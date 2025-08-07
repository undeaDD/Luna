# Celestial - Movies & TV Shows Search App

A simple SwiftUI app that allows you to search for movies and TV shows using The Movie Database (TMDB) API.

## Features

- 🏠 **Home View**: Welcome screen with navigation
- 📚 **Library View**: Manage your favorite content
- 🔍 **Search View**: Search movies and TV shows with TMDB API integration
  - Real-time search with async/await
  - Filter by movies or TV shows
  - Beautiful card-based results with poster images
  - Loading states and error handling
  - Rating and release date information

## Setup Instructions

### 1. Get TMDB API Key

1. Go to [The Movie Database](https://www.themoviedb.org/)
2. Create a free account
3. Navigate to Settings > API
4. Request an API key (choose "Developer" option)
5. Fill out the required information

### 2. Configure API Key

1. Open `Configuration.swift`
2. Replace `"YOUR_API_KEY_HERE"` with your actual TMDB API key:

```swift
static let tmdbAPIKey = "your_actual_api_key_here"
```

### 3. Build and Run

1. Open `celestial.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press `Cmd+R` to build and run

## Project Structure

```
celestial/
├── ContentView.swift          # Main tab view container
├── HomeView.swift            # Home tab content
├── LibraryView.swift         # Library tab content
├── SearchView.swift          # Search tab with TMDB integration
├── Configuration.swift       # API configuration
├── Models/
│   └── TMDBModels.swift      # Data models for TMDB API
├── Services/
│   └── TMDBService.swift     # Network service for TMDB API
└── Views/
    └── SearchResultCard.swift # Custom view for search results
```

## API Integration

The app uses TMDB's `/search/multi` endpoint to search both movies and TV shows simultaneously. The results include:

- Title/Name
- Overview/Description
- Poster images
- Release dates
- Ratings
- Media type (Movie or TV Show)

## Error Handling

The app includes comprehensive error handling for:

- Network connectivity issues
- Invalid API responses
- Missing API key configuration
- Empty search results

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Active internet connection for API calls

## License

This project is for educational purposes. TMDB API usage is subject to their terms of service.
