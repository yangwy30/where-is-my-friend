import SwiftUI

/// An interactive gallery to browse all 150+ 3D skeuomorphic city emblems and archetypes.
struct CityEmblemGalleryView: View {
    @State private var searchText = ""
    @State private var selectedFilter: GalleryFilter = .all
    @State private var selectedCity: CatalogCityItem?

    enum GalleryFilter: String, CaseIterable, Identifiable {
        case all = "All (150+)"
        case custom3D = "3D Crafted"
        case unitedStates = "United States"
        case international = "Global"

        var id: String { rawValue }
    }

    private var cities: [CatalogCityItem] {
        CatalogCityItem.allCities.filter { item in
            let matchesSearch = searchText.isEmpty
                || item.name.localizedCaseInsensitiveContains(searchText)
                || (item.landmark?.localizedCaseInsensitiveContains(searchText) ?? false)
                || item.countryCode.localizedCaseInsensitiveContains(searchText)

            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .custom3D:
                matchesFilter = item.hasCustomAsset
            case .unitedStates:
                matchesFilter = item.countryCode == "US"
            case .international:
                matchesFilter = item.countryCode != "US"
            }

            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(GalleryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, WIFTheme.screenInset)
                .padding(.top, 8)

                // Stats Banner
                HStack {
                    Text("\(cities.count) cities")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.secondaryText)
                    Spacer()
                    Text("30° Isometric · Skeuomorphic")
                        .font(.caption2)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                .padding(.horizontal, WIFTheme.screenInset)

                // 2-Column Responsive Grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 14
                ) {
                    ForEach(cities) { city in
                        Button {
                            selectedCity = city
                        } label: {
                            cityCard(city)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, WIFTheme.screenInset)
                .padding(.bottom, 30)
            }
        }
        .searchable(text: $searchText, prompt: "Search cities, landmarks, or countries")
        .wifAmbientBackground()
        .navigationTitle("City Emblem Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedCity) { city in
            cityDetailSheet(city)
                .presentationDetents([.medium])
        }
    }

    private func cityCard(_ city: CatalogCityItem) -> some View {
        VStack(spacing: 8) {
            CityEmblemView(city: city.name, countryCode: city.countryCode, size: 100)
                .padding(.top, 10)

            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(city.flag)
                        .font(.caption)
                    Text(city.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)
                }

                if let landmark = city.landmark {
                    Text(landmark)
                        .font(.caption2)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .wifGlassSurface(
            tint: city.hasCustomAsset ? WIFTheme.fresh.opacity(0.12) : WIFTheme.surface.opacity(0.08),
            in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
        )
    }

    private func cityDetailSheet(_ city: CatalogCityItem) -> some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            CityEmblemView(city: city.name, countryCode: city.countryCode, size: 130)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(city.flag)
                        .font(.title3)
                    Text(city.name)
                        .font(.title2.weight(.bold))
                }

                if city.hasCustomAsset {
                    Label("Custom 3D Sculpted Diorama", systemImage: "cube.transparent.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)
                } else {
                    Label("Procedural Archetype · \(city.archetype.rawValue.capitalized)", systemImage: "sparkles")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let landmark = city.landmark {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("3D Hero Landmark:").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(landmark).font(.caption.weight(.medium))
                    }
                    if let accent = city.accent {
                        HStack {
                            Text("Miniature Accent:").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(accent).font(.caption.weight(.medium))
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .wifAmbientBackground()
    }
}

// MARK: - Catalog Item Model

struct CatalogCityItem: Identifiable, Sendable {
    let id: String
    let name: String
    let countryCode: String
    let landmark: String?
    let accent: String?
    let archetype: CityArchetype

    var flag: String {
        let base : UInt32 = 127397
        var s = ""
        for v in countryCode.uppercased().unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return s
    }

    var hasCustomAsset: Bool {
        let emblem = CityEmblem.resolve(city: name, countryCode: countryCode)
        return emblem.assetName != nil
    }

    static let allCities: [CatalogCityItem] = [
        CatalogCityItem(id: "new_york", name: "New York", countryCode: "US", landmark: "Empire State Building", accent: "Yellow taxi cab", archetype: .metropolis),
        CatalogCityItem(id: "tokyo", name: "Tokyo", countryCode: "JP", landmark: "Tokyo Tower", accent: "Sakura cherry blossom", archetype: .asian),
        CatalogCityItem(id: "london", name: "London", countryCode: "GB", landmark: "Big Ben clock tower", accent: "Red double-decker bus", archetype: .european),
        CatalogCityItem(id: "paris", name: "Paris", countryCode: "FR", landmark: "Eiffel Tower", accent: "Park street tree", archetype: .european),
        CatalogCityItem(id: "san_francisco", name: "San Francisco", countryCode: "US", landmark: "Golden Gate Bridge", accent: "Vintage cable car", archetype: .coastal),
        CatalogCityItem(id: "beijing", name: "Beijing", countryCode: "CN", landmark: "Temple of Heaven", accent: "Imperial red wall & cypress", archetype: .asian),
        CatalogCityItem(id: "los_angeles", name: "Los Angeles", countryCode: "US", landmark: "Griffith Observatory", accent: "California palm tree", archetype: .coastal),
        CatalogCityItem(id: "chicago", name: "Chicago", countryCode: "US", landmark: "Willis Tower & The Bean", accent: "Elevated 'L' train", archetype: .metropolis),
        CatalogCityItem(id: "seattle", name: "Seattle", countryCode: "US", landmark: "Space Needle", accent: "Evergreen pine tree", archetype: .coastal),
        CatalogCityItem(id: "boston", name: "Boston", countryCode: "US", landmark: "Custom House Tower", accent: "Freedom Trail red line", archetype: .european),
        CatalogCityItem(id: "miami", name: "Miami", countryCode: "US", landmark: "Ocean Drive Art Deco Hotel", accent: "Neon flamingo & palm", archetype: .coastal),
        CatalogCityItem(id: "honolulu", name: "Honolulu", countryCode: "US", landmark: "Diamond Head crater", accent: "Surfboard & hibiscus", archetype: .coastal),
        CatalogCityItem(id: "las_vegas", name: "Las Vegas", countryCode: "US", landmark: "Welcome to Las Vegas Sign", accent: "Golden roulette wheel", archetype: .desert),
        CatalogCityItem(id: "shanghai", name: "Shanghai", countryCode: "CN", landmark: "Oriental Pearl Tower", accent: "The Bund granite facade", archetype: .metropolis),
        CatalogCityItem(id: "hong_kong", name: "Hong Kong", countryCode: "HK", landmark: "Bank of China Tower", accent: "Victoria Harbour junk boat", archetype: .metropolis),
        CatalogCityItem(id: "singapore", name: "Singapore", countryCode: "SG", landmark: "Marina Bay Sands", accent: "Merlion statue", archetype: .coastal),
        CatalogCityItem(id: "seoul", name: "Seoul", countryCode: "KR", landmark: "N Seoul Tower", accent: "Gyeongbokgung gate", archetype: .asian),
        CatalogCityItem(id: "rome", name: "Rome", countryCode: "IT", landmark: "Colosseum", accent: "Vespa scooter", archetype: .european),
        CatalogCityItem(id: "sydney", name: "Sydney", countryCode: "AU", landmark: "Sydney Opera House", accent: "Harbour Bridge arch", archetype: .coastal),
        CatalogCityItem(id: "dubai", name: "Dubai", countryCode: "AE", landmark: "Burj Khalifa", accent: "Burj Al Arab hotel", archetype: .desert),
        CatalogCityItem(id: "amsterdam", name: "Amsterdam", countryCode: "NL", landmark: "Canal Houses & Windmill", accent: "Classic Dutch bicycle", archetype: .european),
        CatalogCityItem(id: "berlin", name: "Berlin", countryCode: "DE", landmark: "Brandenburg Gate", accent: "Berliner Fernsehturm TV tower", archetype: .european)
    ]
}

#Preview {
    NavigationStack {
        CityEmblemGalleryView()
    }
}
