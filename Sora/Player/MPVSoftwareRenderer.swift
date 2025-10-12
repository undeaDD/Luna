//
//  MPVSoftwareRenderer.swift
//  test
//
//  Created by Francesco on 28/09/25.
//

import Libmpv
import CoreMedia
import CoreVideo
import AVFoundation

protocol MPVSoftwareRendererDelegate: AnyObject {
    func renderer(_ renderer: MPVSoftwareRenderer, didUpdatePosition position: Double, duration: Double)
    func renderer(_ renderer: MPVSoftwareRenderer, didChangePause isPaused: Bool)
}

final class MPVSoftwareRenderer {
    enum RendererError: Error {
        case mpvCreationFailed
        case mpvInitialization(Int32)
        case renderContextCreation(Int32)
    }
    
    private let displayLayer: AVSampleBufferDisplayLayer
    private let renderQueue = DispatchQueue(label: "mpv.software.render", qos: .userInitiated)
    private let eventQueue = DispatchQueue(label: "mpv.software.events", qos: .utility)
    private let stateQueue = DispatchQueue(label: "mpv.software.state", attributes: .concurrent)
    private let eventQueueGroup = DispatchGroup()
    private let renderQueueKey = DispatchSpecificKey<Void>()
    
    private var dimensionsArray = [Int32](repeating: 0, count: 2)
    private var renderParams = [mpv_render_param](repeating: mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil), count: 5)
    
    private var mpv: OpaquePointer?
    private var renderContext: OpaquePointer?
    private var videoSize: CGSize = .zero
    private var pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPoolAuxAttributes: CFDictionary?
    private var colorState = ColorState()
    private var formatDescription: CMVideoFormatDescription?
    private var didFlushForFormatChange = false
    private var poolWidth: Int = 0
    private var poolHeight: Int = 0
    private var preAllocatedBuffers: [CVPixelBuffer] = []
    private let maxPreAllocatedBuffers = 6
    
    private var currentPreset: PlayerPreset?
    private var currentURL: URL?
    private var currentHeaders: [String: String]?
    
    private var disposeBag: [() -> Void] = []
    
    private var isRunning = false
    private var isStopping = false
    private var shouldClearPixelBuffer = false
    private let bgraFormatCString: [CChar] = Array("bgra\0".utf8CString)
    
    weak var delegate: MPVSoftwareRendererDelegate?
    private var cachedDuration: Double = 0
    private var cachedPosition: Double = 0
    private var isPaused: Bool = true
    private var lastWantsExtendedDynamicRangeContent: Bool = false
    private var isRenderScheduled = false
    private var lastRenderTime: CFTimeInterval = 0
    private let minRenderInterval: CFTimeInterval = 1.0 / 120.0
    
    var isPausedState: Bool {
        return isPaused
    }
    
    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        renderQueue.setSpecific(key: renderQueueKey, value: ())
    }
    
    deinit {
        stop()
    }
    
    func start() throws {
        guard !isRunning else { return }
        guard let handle = mpv_create() else {
            throw RendererError.mpvCreationFailed
        }
        mpv = handle
        setOption(name: "terminal", value: "yes")
        setOption(name: "msg-level", value: "status")
        setOption(name: "keep-open", value: "yes")
        setOption(name: "idle", value: "yes")
        setOption(name: "vo", value: "libmpv")
        setOption(name: "hwdec", value: "videotoolbox-copy")
        setOption(name: "gpu-api", value: "metal")
        setOption(name: "gpu-context", value: "metal")
        setOption(name: "demuxer-thread", value: "yes")
        setOption(name: "ytdl", value: "yes")
        
        let initStatus = mpv_initialize(handle)
        guard initStatus >= 0 else {
            throw RendererError.mpvInitialization(initStatus)
        }
        
        mpv_request_log_messages(handle, "warn")
        
        try createRenderContext()
        observeProperties()
        installWakeupHandler()
        isRunning = true
    }
    
    func stop() {
        if isStopping { return }
        if !isRunning, mpv == nil { return }
        isRunning = false
        isStopping = true
        
        var handleForShutdown: OpaquePointer?
        
        renderQueue.sync { [weak self] in
            guard let self else { return }
            
            if let ctx = self.renderContext {
                mpv_render_context_set_update_callback(ctx, nil, nil)
                mpv_render_context_free(ctx)
                self.renderContext = nil
            }
            
            handleForShutdown = self.mpv
            if let handle = handleForShutdown {
                mpv_set_wakeup_callback(handle, nil, nil)
                self.command(handle, ["quit"])
                mpv_wakeup(handle)
            }
            
            self.formatDescription = nil
            self.preAllocatedBuffers.removeAll()
            self.pixelBufferPool = nil
            self.poolWidth = 0
            self.poolHeight = 0
        }
        
        eventQueueGroup.wait()
        
        renderQueue.sync { [weak self] in
            guard let self else { return }
            
            if let handle = handleForShutdown {
                mpv_destroy(handle)
            }
            self.mpv = nil
            
            self.disposeBag.forEach { $0() }
            self.disposeBag.removeAll()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.displayLayer.flushAndRemoveImage()
        }
        
        isStopping = false
    }
    
    func load(url: URL, with preset: PlayerPreset, headers: [String: String]? = nil) {
        currentPreset = preset
        currentURL = url
        currentHeaders = headers
        
        guard let handle = mpv else { return }
        
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.apply(commands: preset.commands, on: handle)
            self.command(handle, ["stop"])
            self.updateHTTPHeaders(headers)
            
            var finalURL = url
            if !url.isFileURL {
                finalURL = url
            }
            
            let target = finalURL.isFileURL ? finalURL.path : finalURL.absoluteString
            self.command(handle, ["loadfile", target, "replace"])
        }
    }
    
    func reloadCurrentItem() {
        guard let url = currentURL, let preset = currentPreset else { return }
        load(url: url, with: preset, headers: currentHeaders)
    }
    
    func applyPreset(_ preset: PlayerPreset) {
        currentPreset = preset
        guard let handle = mpv else { return }
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.apply(commands: preset.commands, on: handle)
        }
    }
    
    private func setOption(name: String, value: String) {
        guard let handle = mpv else { return }
        _ = value.withCString { valuePointer in
            name.withCString { namePointer in
                mpv_set_option_string(handle, namePointer, valuePointer)
            }
        }
    }
    
    private func setProperty(name: String, value: String) {
        guard let handle = mpv else { return }
        _ = value.withCString { valuePointer in
            name.withCString { namePointer in
                mpv_set_property_string(handle, namePointer, valuePointer)
            }
        }
    }
    
    private func clearProperty(name: String) {
        guard let handle = mpv else { return }
        name.withCString { namePointer in
            mpv_set_property(handle, namePointer, MPV_FORMAT_NONE, nil)
        }
    }
    
    private func updateHTTPHeaders(_ headers: [String: String]?) {
        guard let headers, !headers.isEmpty else {
            clearProperty(name: "http-header-fields")
            return
        }
        
        let headerString = headers
            .map { key, value in
                "\(key): \(value)"
            }
            .joined(separator: "\r\n")
        setProperty(name: "http-header-fields", value: headerString)
    }
    
    private func createRenderContext() throws {
        guard let handle = mpv else { return }
        
        var apiType = MPV_RENDER_API_TYPE_SW
        let status = withUnsafePointer(to: &apiType) { apiTypePtr in
            var params = [
                mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(mutating: apiTypePtr)),
                mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
            ]
            
            return params.withUnsafeMutableBufferPointer { pointer -> Int32 in
                pointer.baseAddress?.withMemoryRebound(to: mpv_render_param.self, capacity: pointer.count) { parameters in
                    return mpv_render_context_create(&renderContext, handle, parameters)
                } ?? -1
            }
        }
        
        guard status >= 0, renderContext != nil else {
            throw RendererError.renderContextCreation(status)
        }
        
        mpv_render_context_set_update_callback(renderContext, { context in
            guard let context = context else { return }
            let instance = Unmanaged<MPVSoftwareRenderer>.fromOpaque(context).takeUnretainedValue()
            instance.scheduleRender()
        }, Unmanaged.passUnretained(self).toOpaque())
    }
    
    private func observeProperties() {
        guard let handle = mpv else { return }
        let properties: [(String, mpv_format)] = [
            ("dwidth", MPV_FORMAT_INT64),
            ("dheight", MPV_FORMAT_INT64),
            ("duration", MPV_FORMAT_DOUBLE),
            ("time-pos", MPV_FORMAT_DOUBLE),
            ("pause", MPV_FORMAT_FLAG),
            ("video-params/primaries", MPV_FORMAT_STRING),
            ("video-params/transfer", MPV_FORMAT_STRING),
            ("video-params/colormatrix", MPV_FORMAT_STRING),
            ("video-params/colorlevels", MPV_FORMAT_STRING),
            ("video-params/sig-peak", MPV_FORMAT_DOUBLE)
        ]
        
        for (name, format) in properties {
            _ = name.withCString { pointer in
                mpv_observe_property(handle, 0, pointer, format)
            }
        }
    }
    
    private func installWakeupHandler() {
        guard let handle = mpv else { return }
        mpv_set_wakeup_callback(handle, { userdata in
            guard let userdata else { return }
            let instance = Unmanaged<MPVSoftwareRenderer>.fromOpaque(userdata).takeUnretainedValue()
            instance.processEvents()
        }, Unmanaged.passUnretained(self).toOpaque())
        renderQueue.async { [weak self] in
            guard let self else { return }
            self.disposeBag.append { [weak self] in
                guard let self, let handle = self.mpv else { return }
                mpv_set_wakeup_callback(handle, nil, nil)
            }
        }
    }
    
    private func scheduleRender() {
        renderQueue.async { [weak self] in
            guard let self, self.isRunning, !self.isStopping else { return }
            
            let currentTime = CACurrentMediaTime()
            if self.isRenderScheduled && (currentTime - self.lastRenderTime) < self.minRenderInterval {
                return
            }
            
            self.isRenderScheduled = true
            self.lastRenderTime = currentTime
            self.performRenderUpdate()
            self.isRenderScheduled = false
        }
    }
    
    private func performRenderUpdate() {
        guard let context = renderContext else { return }
        let status = mpv_render_context_update(context)
        
        let updateFlags = UInt32(status)
        
        if updateFlags & MPV_RENDER_UPDATE_FRAME.rawValue != 0 {
            renderFrame()
        }
        
        if status > 0 {
            scheduleRender()
        }
    }
    
    private func renderFrame() {
        guard let context = renderContext else { return }
        let size = currentVideoSize()
        guard size.width > 0, size.height > 0 else { return }
        
        let width = Int(size.width)
        let height = Int(size.height)
        
        if poolWidth != width || poolHeight != height {
            recreatePixelBufferPool(width: width, height: height)
        }
        
        var pixelBuffer: CVPixelBuffer?
        var status: CVReturn = kCVReturnError
        
        if !preAllocatedBuffers.isEmpty {
            pixelBuffer = preAllocatedBuffers.removeFirst()
            status = kCVReturnSuccess
        } else if let pool = pixelBufferPool {
            status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, pixelBufferPoolAuxAttributes, &pixelBuffer)
        }
        
        if status != kCVReturnSuccess || pixelBuffer == nil {
            let attrs = [
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
            ] as CFDictionary
            status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        }
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return
        }
        
        if shouldClearPixelBuffer {
            let bufferDataSize = CVPixelBufferGetDataSize(buffer)
            memset(baseAddress, 0, bufferDataSize)
            shouldClearPixelBuffer = false
        }
        
        applyColorAttachments(to: buffer)
        
        dimensionsArray[0] = Int32(width)
        dimensionsArray[1] = Int32(height)
        let stride = Int32(CVPixelBufferGetBytesPerRow(buffer))
        let expectedMinStride = Int32(width * 4)
        if stride < expectedMinStride {
            Logger.shared.log("Unexpected pixel buffer stride \(stride) < expected \(expectedMinStride) — skipping render to avoid memory corruption", type: "Error")
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return
        }
        
        let pointerValue = baseAddress
        dimensionsArray.withUnsafeMutableBufferPointer { dimsPointer in
            bgraFormatCString.withUnsafeBufferPointer { formatPointer in
                withUnsafePointer(to: stride) { stridePointer in
                    renderParams[0] = mpv_render_param(type: MPV_RENDER_PARAM_SW_SIZE, data: UnsafeMutableRawPointer(dimsPointer.baseAddress))
                    renderParams[1] = mpv_render_param(type: MPV_RENDER_PARAM_SW_FORMAT, data: UnsafeMutableRawPointer(mutating: formatPointer.baseAddress))
                    renderParams[2] = mpv_render_param(type: MPV_RENDER_PARAM_SW_STRIDE, data: UnsafeMutableRawPointer(mutating: stridePointer))
                    renderParams[3] = mpv_render_param(type: MPV_RENDER_PARAM_SW_POINTER, data: pointerValue)
                    renderParams[4] = mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                    
                    let rc = mpv_render_context_render(context, &renderParams)
                    if rc < 0 {
                        Logger.shared.log("mpv_render_context_render returned error \(rc)", type: "Error")
                    }
                }
            }
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        enqueue(buffer: buffer)
        
        if preAllocatedBuffers.count < 2 {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.preAllocateBuffers()
            }
        }
    }
    
    private func createPixelBufferPool(width: Int, height: Int) {
        let pixelFormat = kCVPixelFormatType_32BGRA
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormat,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ]
        
        let poolAttrs: [CFString: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey: 6,
            kCVPixelBufferPoolMaximumBufferAgeKey: 0
        ]
        
        let auxAttrs: [CFString: Any] = [
            kCVPixelBufferPoolAllocationThresholdKey: 4
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttrs as CFDictionary, attrs as CFDictionary, &pool)
        if status == kCVReturnSuccess, let pool {
            renderQueueSync {
                self.pixelBufferPool = pool
                self.pixelBufferPoolAuxAttributes = auxAttrs as CFDictionary
                self.poolWidth = width
                self.poolHeight = height
            }
            
            preAllocateBuffers()
        } else {
            Logger.shared.log("Failed to create CVPixelBufferPool (\(status))", type: "Error")
        }
    }
    
    private func recreatePixelBufferPool(width: Int, height: Int) {
        renderQueueSync {
            self.preAllocatedBuffers.removeAll()
            
            self.pixelBufferPool = nil
            self.formatDescription = nil
        }
        
        createPixelBufferPool(width: width, height: height)
    }
    
    private func preAllocateBuffers() {
        guard let pool = pixelBufferPool else { return }
        
        let targetCount = min(maxPreAllocatedBuffers, 4)
        let currentCount = preAllocatedBuffers.count
        
        guard currentCount < targetCount else { return }
        
        let bufferCount = targetCount - currentCount
        
        for _ in 0..<bufferCount {
            var buffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
                kCFAllocatorDefault,
                pool,
                pixelBufferPoolAuxAttributes,
                &buffer
            )
            
            if status == kCVReturnSuccess, let buffer = buffer {
                renderQueue.async { [weak self] in
                    guard let self = self else { return }
                    if self.preAllocatedBuffers.count < self.maxPreAllocatedBuffers {
                        self.preAllocatedBuffers.append(buffer)
                    }
                }
            } else {
                break
            }
        }
    }
    
    private func enqueue(buffer: CVPixelBuffer) {
        _ = CVImageBufferGetEncodedSize(buffer)
        let needsFlush = updateFormatDescriptionIfNeeded(for: buffer)
        let presentationTime = CMClockGetTime(CMClockGetHostTimeClock())
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
        
        var sampleBuffer: CMSampleBuffer?
        guard let formatDescription = formatDescription else {
            Logger.shared.log("Missing formatDescription when creating sample buffer — skipping frame", type: "Error")
            return
        }
        let result = CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription, sampleTiming: &timing, sampleBufferOut: &sampleBuffer)
        
        guard result == noErr, let sample = sampleBuffer else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if needsFlush {
                self.displayLayer.flushAndRemoveImage()
                self.didFlushForFormatChange = true
            } else if self.didFlushForFormatChange {
                self.displayLayer.flush()
                self.didFlushForFormatChange = false
            }
            
            if self.displayLayer.controlTimebase == nil {
                var timebase: CMTimebase?
                if CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase) == noErr, let timebase {
                    CMTimebaseSetRate(timebase, rate: 1.0)
                    CMTimebaseSetTime(timebase, time: presentationTime)
                    self.displayLayer.controlTimebase = timebase
                } else {
                    Logger.shared.log("Failed to create control timebase", type: "Error")
                }
            }
            
            if self.displayLayer.status == .failed {
                self.displayLayer.flushAndRemoveImage()
            }
            
            self.displayLayer.enqueue(sample)
        }
    }
    
    private func updateFormatDescriptionIfNeeded(for buffer: CVPixelBuffer) -> Bool {
        var didChange = false
        let width = Int32(CVPixelBufferGetWidth(buffer))
        let height = Int32(CVPixelBufferGetHeight(buffer))
        renderQueueSync {
            if let description = formatDescription {
                let currentDimensions = CMVideoFormatDescriptionGetDimensions(description)
                if currentDimensions.width != width || currentDimensions.height != height {
                    formatDescription = nil
                }
            }
            
            if formatDescription == nil {
                var newDescription: CMVideoFormatDescription?
                if CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &newDescription) == noErr, let newDescription {
                    formatDescription = newDescription
                    didChange = true
                }
            }
        }
        return didChange
    }
    
    private func renderQueueSync(_ block: () -> Void) {
        if DispatchQueue.getSpecific(key: renderQueueKey) != nil {
            block()
        } else {
            renderQueue.sync(execute: block)
        }
    }
    
    private func currentVideoSize() -> CGSize {
        stateQueue.sync {
            videoSize
        }
    }
    
    private func updateVideoSize(width: Int, height: Int) {
        let size = CGSize(width: max(width, 0), height: max(height, 0))
        stateQueue.async(flags: .barrier) {
            self.videoSize = size
        }
        renderQueue.async { [weak self] in
            guard let self else { return }
            
            if self.poolWidth != width || self.poolHeight != height {
                self.recreatePixelBufferPool(width: max(width, 0), height: max(height, 0))
            }
        }
    }
    
    private func updateColorState(transform: @escaping (inout ColorState) -> Void) {
        stateQueue.async(flags: .barrier) {
            transform(&self.colorState)
        }
    }
    
    private func snapshotColorState() -> ColorState {
        stateQueue.sync { colorState }
    }
    
    private func applyColorAttachments(to buffer: CVPixelBuffer) {
        let state = snapshotColorState()
        
        if let primaries = state.primaries, let value = primaries.cvValue {
            CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, value, .shouldPropagate)
        }
        
        if let transfer = state.transfer, let value = transfer.cvValue {
            CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, value, .shouldPropagate)
        }
        
        if let matrix = state.matrix, let value = matrix.cvValue {
            CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, value, .shouldPropagate)
        }
        
        if #available(iOS 17.0, *) {
            let wantsEDR = (state.signalPeak ?? 0.0) > 1.0
            if wantsEDR != lastWantsExtendedDynamicRangeContent {
                lastWantsExtendedDynamicRangeContent = wantsEDR
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.displayLayer.wantsExtendedDynamicRangeContent = wantsEDR
                }
            }
            
            if wantsEDR, let sigPeak = state.signalPeak {
                let masteringDict: [String: Any] = [
                    "MasteringDisplayMaximumLuminance": sigPeak * 10000.0,
                    "MasteringDisplayMinimumLuminance": 0.05
                ]
                CVBufferSetAttachment(buffer, kCVImageBufferMasteringDisplayColorVolumeKey, masteringDict as CFDictionary, .shouldPropagate)
            }
        }
    }
    
    private func apply(commands: [[String]], on handle: OpaquePointer) {
        for command in commands {
            guard !command.isEmpty else { continue }
            self.command(handle, command)
        }
    }
    
    private func command(_ handle: OpaquePointer, _ args: [String]) {
        guard !args.isEmpty else { return }
        _ = withCStringArray(args) { pointer in
            mpv_command_async(handle, 0, pointer)
        }
    }
    
    private func processEvents() {
        eventQueueGroup.enter()
        let group = eventQueueGroup
        eventQueue.async { [weak self] in
            defer { group.leave() }
            guard let self else { return }
            while !self.isStopping {
                guard let handle = self.mpv else { return }
                guard let eventPointer = mpv_wait_event(handle, 0) else { return }
                let event = eventPointer.pointee
                if event.event_id == MPV_EVENT_NONE { continue }
                self.handleEvent(event)
                if event.event_id == MPV_EVENT_SHUTDOWN { break }
            }
        }
    }
    
    private func handleEvent(_ event: mpv_event) {
        switch event.event_id {
        case MPV_EVENT_VIDEO_RECONFIG:
            refreshVideoState()
        case MPV_EVENT_PROPERTY_CHANGE:
            if let property = event.data?.assumingMemoryBound(to: mpv_event_property.self).pointee.name {
                let name = String(cString: property)
                refreshProperty(named: name)
            }
        case MPV_EVENT_SHUTDOWN:
            Logger.shared.log("mpv shutdown", type: "Warn")
        case MPV_EVENT_LOG_MESSAGE:
            if let logMessagePointer = event.data?.assumingMemoryBound(to: mpv_event_log_message.self) {
                let component = String(cString: logMessagePointer.pointee.prefix)
                let text = String(cString: logMessagePointer.pointee.text)
                let lower = text.lowercased()
                if lower.contains("error") {
                    Logger.shared.log("mpv[\(component)] \(text)", type: "Error")
                } else if lower.contains("warn") || lower.contains("warning") || lower.contains("deprecated") {
                    Logger.shared.log("mpv[\(component)] \(text)", type: "Warn")
                }
            }
        default:
            break
        }
    }
    
    private func refreshVideoState() {
        guard let handle = mpv else { return }
        var width: Int64 = 0
        var height: Int64 = 0
        getProperty(handle: handle, name: "dwidth", format: MPV_FORMAT_INT64, value: &width)
        getProperty(handle: handle, name: "dheight", format: MPV_FORMAT_INT64, value: &height)
        updateVideoSize(width: Int(width), height: Int(height))
    }
    
    private func refreshProperty(named name: String) {
        guard let handle = mpv else { return }
        switch name {
        case "duration":
            var value = Double(0)
            let status = getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value)
            if status >= 0 {
                cachedDuration = value
                delegate?.renderer(self, didUpdatePosition: cachedPosition, duration: cachedDuration)
            }
        case "time-pos":
            var value = Double(0)
            let status = getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &value)
            if status >= 0 {
                cachedPosition = value
                delegate?.renderer(self, didUpdatePosition: cachedPosition, duration: cachedDuration)
            }
        case "pause":
            var flag: Int32 = 0
            let status = getProperty(handle: handle, name: name, format: MPV_FORMAT_FLAG, value: &flag)
            if status >= 0 {
                let newPaused = flag != 0
                if newPaused != isPaused {
                    isPaused = newPaused
                    delegate?.renderer(self, didChangePause: isPaused)
                }
            }
        case "video-params/primaries":
            let value = getStringProperty(handle: handle, name: name)
            let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            updateColorState { state in
                state.primaries = normalized.flatMap(ColorPrimaries.fromString(_:))
            }
        case "video-params/transfer":
            let value = getStringProperty(handle: handle, name: name)
            let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            updateColorState { state in
                state.transfer = normalized.flatMap(ColorTransfer.fromString(_:))
            }
        case "video-params/colormatrix":
            let value = getStringProperty(handle: handle, name: name)
            let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            updateColorState { state in
                state.matrix = normalized.flatMap(ColorMatrix.fromString(_:))
            }
        case "video-params/colorlevels":
            let value = getStringProperty(handle: handle, name: name)
            updateColorState { state in
                state.levels = value.flatMap(ColorLevels.init(rawValue:))
            }
        case "video-params/sig-peak":
            var doubleValue = Double(0)
            let status = getProperty(handle: handle, name: name, format: MPV_FORMAT_DOUBLE, value: &doubleValue)
            if status >= 0 {
                updateColorState { state in
                    state.signalPeak = doubleValue
                }
            }
        default:
            break
        }
    }
    
    private func getStringProperty(handle: OpaquePointer, name: String) -> String? {
        var result: String?
        name.withCString { pointer in
            if let cString = mpv_get_property_string(handle, pointer) {
                result = String(cString: cString)
                mpv_free(cString)
            }
        }
        return result
    }
    
    @discardableResult
    private func getProperty<T>(handle: OpaquePointer, name: String, format: mpv_format, value: inout T) -> Int32 {
        return name.withCString { pointer in
            return withUnsafeMutablePointer(to: &value) { mutablePointer in
                return mpv_get_property(handle, pointer, format, mutablePointer)
            }
        }
    }
    
    @inline(__always)
    private func withCStringArray<R>(_ args: [String], body: (UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> R) -> R {
        var cStrings = [UnsafeMutablePointer<CChar>?]()
        cStrings.reserveCapacity(args.count + 1)
        for s in args {
            cStrings.append(strdup(s))
        }
        cStrings.append(nil)
        defer {
            for ptr in cStrings where ptr != nil {
                free(ptr)
            }
        }
        
        return cStrings.withUnsafeMutableBufferPointer { buffer in
            return buffer.baseAddress!.withMemoryRebound(to: UnsafePointer<CChar>?.self, capacity: buffer.count) { rebound in
                return body(UnsafeMutablePointer(mutating: rebound))
            }
        }
    }
    
    // MARK: - Playback Controls
    func play() {
        setProperty(name: "pause", value: "no")
    }
    func pausePlayback() {
        setProperty(name: "pause", value: "yes")
    }
    func togglePause() {
        if isPaused { play() } else { pausePlayback() }
    }
    func seek(to seconds: Double) {
        guard let handle = mpv else { return }
        let clamped = max(0, seconds)
        command(handle, ["seek", String(clamped), "absolute"])
    }
    func seek(by seconds: Double) {
        guard let handle = mpv else { return }
        command(handle, ["seek", String(seconds), "relative"])
    }
}

// MARK: - Color State

private struct ColorState {
    var primaries: ColorPrimaries? = nil
    var transfer: ColorTransfer? = nil
    var matrix: ColorMatrix? = nil
    var levels: ColorLevels? = nil
    var signalPeak: Double? = nil
}

private enum ColorPrimaries: String {
    case bt709 = "bt.709"
    case bt2020 = "bt.2020"
    case smpte170m = "smpte170m"
    case bt601 = "bt.601"
    
    var cvValue: CFString? {
        switch self {
        case .bt709, .smpte170m:
            return kCVImageBufferColorPrimaries_ITU_R_709_2
        case .bt2020:
            return kCVImageBufferColorPrimaries_ITU_R_2020
        case .bt601:
            return kCVImageBufferColorPrimaries_SMPTE_C
        }
    }
    
    static func fromString(_ s: String) -> ColorPrimaries? {
        if s.contains("2020") { return .bt2020 }
        if s.contains("709") { return .bt709 }
        if s.contains("170") || s.contains("smpte170") { return .smpte170m }
        if s.contains("601") { return .bt601 }
        return nil
    }
}

private enum ColorTransfer: String {
    case bt1886 = "bt.1886"
    case bt2020_10 = "bt.2020-10"
    case bt2020_12 = "bt.2020-12"
    case srgb = "srgb"
    case linear = "linear"
    case pq = "pq"
    case hlg = "hlg"
    case smpte2084 = "smpte2084"
    case dolby = "dolby"
    
    var cvValue: CFString? {
        switch self {
        case .bt1886, .bt2020_10, .bt2020_12, .srgb:
            return kCVImageBufferTransferFunction_ITU_R_709_2
        case .linear:
            return kCVImageBufferTransferFunction_Linear
        case .pq, .smpte2084, .dolby:
            return kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ
        case .hlg:
            return kCVImageBufferTransferFunction_ITU_R_2100_HLG
        }
    }
    
    static func fromString(_ s: String) -> ColorTransfer? {
        if s.contains("pq") || s.contains("smpte2084") || s.contains("2084") { return .pq }
        if s.contains("hlg") { return .hlg }
        if s.contains("dolby") { return .dolby }
        if s.contains("1886") { return .bt1886 }
        if s.contains("2020") { return .bt2020_10 }
        if s.contains("srgb") { return .srgb }
        if s.contains("linear") { return .linear }
        return nil
    }
}

private enum ColorMatrix: String {
    case bt601 = "bt.601"
    case bt709 = "bt.709"
    case bt2020NCL = "bt.2020nc"
    case bt2020 = "bt.2020"
    
    var cvValue: CFString? {
        switch self {
        case .bt601:
            return kCVImageBufferYCbCrMatrix_ITU_R_601_4
        case .bt709:
            return kCVImageBufferYCbCrMatrix_ITU_R_709_2
        case .bt2020, .bt2020NCL:
            return kCVImageBufferYCbCrMatrix_ITU_R_2020
        }
    }
    
    static func fromString(_ s: String) -> ColorMatrix? {
        if s.contains("2020") { return .bt2020 }
        if s.contains("709") { return .bt709 }
        if s.contains("601") { return .bt601 }
        return nil
    }
}

private enum ColorLevels: String {
    case limited
    case full
}
