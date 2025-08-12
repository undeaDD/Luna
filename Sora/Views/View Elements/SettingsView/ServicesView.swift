//
//  ServicesView.swift
//  Sora
//
//  Created by Francesco on 09/08/25.
//

import SwiftUI
import Kingfisher

struct ServicesView: View {
    @StateObject private var serviceManager = ServiceManager.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if serviceManager.services.isEmpty {
                    emptyStateView
                } else {
                    servicesList
                }
            }
            .navigationTitle("Services")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Services")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var servicesList: some View {
        List {
            ForEach(serviceManager.services) { service in
                ServiceRow(service: service, serviceManager: serviceManager)
            }
            .onDelete(perform: deleteServices)
        }
    }
    
    private func deleteServices(offsets: IndexSet) {
        for index in offsets {
            let service = serviceManager.services[index]
            serviceManager.removeService(service)
        }
    }
}

struct ServiceRow: View {
    let service: Services
    let serviceManager: ServiceManager
    
    var body: some View {
        HStack(spacing: 12) {
            KFImage(URL(string: service.metadata.iconUrl))
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "app.dashed")
                                .foregroundColor(.secondary)
                        )
                }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(service.isActive ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(service.metadata.sourceName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack {
                    Text("by \(service.metadata.author.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("v\(service.metadata.version)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
                
                HStack(spacing: 8) {
                    Text(service.metadata.language.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(service.metadata.streamType.capitalized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                    
                    if service.isActive {
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
            }
            
            Toggle("", isOn: Binding(
                get: {
                    service.isActive
                },
                set: { newValue in
                    serviceManager.toggleServiceState(service)
                }
            ))
#if os(iOS)
            .toggleStyle(SwitchToggleStyle(tint: .green))
#endif
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ServicesView()
}
