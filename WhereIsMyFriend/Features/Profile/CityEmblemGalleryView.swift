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
        CatalogCityItem(id: "new_york", name: "New York", countryCode: "US", landmark: "Empire State Building", accent: "iconic yellow taxi cab", archetype: .metropolis),
        CatalogCityItem(id: "los_angeles", name: "Los Angeles", countryCode: "US", landmark: "Griffith Observatory", accent: "tall California palm tree", archetype: .metropolis),
        CatalogCityItem(id: "chicago", name: "Chicago", countryCode: "US", landmark: "Willis Tower and Cloud Gate bean sculpture", accent: "miniature 'L' elevated train", archetype: .metropolis),
        CatalogCityItem(id: "houston", name: "Houston", countryCode: "US", landmark: "NASA Space Center Saturn V rocket", accent: "miniature lunar lander capsule", archetype: .metropolis),
        CatalogCityItem(id: "phoenix", name: "Phoenix", countryCode: "US", landmark: "Camelback Mountain red rock silhouette", accent: "giant green Saguaro cactus", archetype: .desert),
        CatalogCityItem(id: "philadelphia", name: "Philadelphia", countryCode: "US", landmark: "Independence Hall brick tower", accent: "Liberty Bell on wooden pedestal", archetype: .metropolis),
        CatalogCityItem(id: "san_antonio", name: "San Antonio", countryCode: "US", landmark: "The Alamo limestone mission facade", accent: "River Walk stone bridge and water", archetype: .desert),
        CatalogCityItem(id: "san_diego", name: "San Diego", countryCode: "US", landmark: "Coronado Bridge over blue bay water", accent: "Balboa Park Spanish tower", archetype: .coastal),
        CatalogCityItem(id: "dallas", name: "Dallas", countryCode: "US", landmark: "Reunion Tower with glowing geodetic sphere", accent: "miniature Pegasus emblem", archetype: .metropolis),
        CatalogCityItem(id: "san_jose", name: "San Jose", countryCode: "US", landmark: "Tech Museum metallic dome", accent: "miniature Silicon Valley silicon wafer", archetype: .metropolis),
        CatalogCityItem(id: "austin", name: "Austin", countryCode: "US", landmark: "Texas State Capitol granite dome", accent: "vintage acoustic guitar", archetype: .metropolis),
        CatalogCityItem(id: "san_francisco", name: "San Francisco", countryCode: "US", landmark: "Golden Gate Bridge international-orange tower", accent: "vintage cable car", archetype: .coastal),
        CatalogCityItem(id: "seattle", name: "Seattle", countryCode: "US", landmark: "Space Needle tower", accent: "emerald evergreen pine tree", archetype: .coastal),
        CatalogCityItem(id: "denver", name: "Denver", countryCode: "US", landmark: "Red Rocks Amphitheatre rock formation", accent: "snow-dusted Rocky Mountain peak", archetype: .alpine),
        CatalogCityItem(id: "washington", name: "Washington, D.C.", countryCode: "US", landmark: "United States Capitol white dome and Washington Monument", accent: "cherry blossom tree", archetype: .metropolis),
        CatalogCityItem(id: "boston", name: "Boston", countryCode: "US", landmark: "Custom House Tower and Quincy Market", accent: "Freedom Trail red brick line", archetype: .metropolis),
        CatalogCityItem(id: "miami", name: "Miami", countryCode: "US", landmark: "Art Deco Ocean Drive pastel hotel", accent: "neon flamingo and palm tree", archetype: .coastal),
        CatalogCityItem(id: "las_vegas", name: "Las Vegas", countryCode: "US", landmark: "Welcome to Fabulous Las Vegas retro sign", accent: "sparkling gold roulette wheel", archetype: .desert),
        CatalogCityItem(id: "honolulu", name: "Honolulu", countryCode: "US", landmark: "Diamond Head volcanic crater", accent: "tropical surfboard and hibiscus flower", archetype: .coastal),
        CatalogCityItem(id: "atlanta", name: "Atlanta", countryCode: "US", landmark: "Bank of America Plaza pencil spire tower", accent: "sweet Georgia peach icon", archetype: .metropolis),
        CatalogCityItem(id: "nashville", name: "Nashville", countryCode: "US", landmark: "Ryman Auditorium brick facade", accent: "vintage country music microphone", archetype: .metropolis),
        CatalogCityItem(id: "new_orleans", name: "New Orleans", countryCode: "US", landmark: "St. Louis Cathedral French Quarter spires", accent: "golden jazz saxophone", archetype: .metropolis),
        CatalogCityItem(id: "portland", name: "Portland", countryCode: "US", landmark: "St. Johns Bridge green Gothic steel arches", accent: "Douglas fir pine tree", archetype: .metropolis),
        CatalogCityItem(id: "minneapolis", name: "Minneapolis", countryCode: "US", landmark: "Spoonbridge and Cherry sculpture", accent: "blue lake water wave", archetype: .metropolis),
        CatalogCityItem(id: "detroit", name: "Detroit", countryCode: "US", landmark: "Renaissance Center glass towers", accent: "classic vintage muscle car", archetype: .metropolis),
        CatalogCityItem(id: "pittsburgh", name: "Pittsburgh", countryCode: "US", landmark: "Three Rivers yellow Roberto Clemente Bridge", accent: "steel beam girder", archetype: .metropolis),
        CatalogCityItem(id: "st_louis", name: "St. Louis", countryCode: "US", landmark: "Gateway Arch stainless steel catenary arch", accent: "Mississippi paddlewheel steamboat", archetype: .metropolis),
        CatalogCityItem(id: "tampa", name: "Tampa", countryCode: "US", landmark: "Tampa Bay sunshine skyway bridge", accent: "gentle manatee in blue water", archetype: .metropolis),
        CatalogCityItem(id: "orlando", name: "Orlando", countryCode: "US", landmark: "Fairytale royal castle spire", accent: "magical sparkling wand star", archetype: .metropolis),
        CatalogCityItem(id: "charlotte", name: "Charlotte", countryCode: "US", landmark: "Bank of America Corporate Center crown tower", accent: "racing checkered flag", archetype: .metropolis),
        CatalogCityItem(id: "salt_lake_city", name: "Salt Lake City", countryCode: "US", landmark: "Salt Lake Temple granite spires", accent: "Wasatch snow-capped mountain ridge", archetype: .metropolis),
        CatalogCityItem(id: "baltimore", name: "Baltimore", countryCode: "US", landmark: "Fort McHenry star fort and Inner Harbor lighthouse", accent: "blue crab icon", archetype: .metropolis),
        CatalogCityItem(id: "kansas_city", name: "Kansas City", countryCode: "US", landmark: "Country Club Plaza Spanish fountain", accent: "BBQ smoker grill", archetype: .metropolis),
        CatalogCityItem(id: "cleveland", name: "Cleveland", countryCode: "US", landmark: "Rock and Roll Hall of Fame glass pyramid", accent: "electric guitar", archetype: .metropolis),
        CatalogCityItem(id: "indianapolis", name: "Indianapolis", countryCode: "US", landmark: "Soldiers and Sailors Monument limestone spire", accent: "IndyCar open-wheel racer", archetype: .metropolis),
        CatalogCityItem(id: "columbus", name: "Columbus", countryCode: "US", landmark: "LeVeque Tower Art Deco terracotta spire", accent: "buckeye nut and leaf", archetype: .metropolis),
        CatalogCityItem(id: "milwaukee", name: "Milwaukee", countryCode: "US", landmark: "Milwaukee Art Museum Quadracci Pavilion white wings", accent: "craft beer mug with foam", archetype: .metropolis),
        CatalogCityItem(id: "cincinnati", name: "Cincinnati", countryCode: "US", landmark: "John A. Roebling Suspension Bridge blue cables", accent: "steamboat paddle wheel", archetype: .metropolis),
        CatalogCityItem(id: "raleigh", name: "Raleigh", countryCode: "US", landmark: "North Carolina State Capitol dome", accent: "oak acorn and green leaf", archetype: .metropolis),
        CatalogCityItem(id: "louisville", name: "Louisville", countryCode: "US", landmark: "Churchill Downs twin spires", accent: "thoroughbred racehorse horseshoe", archetype: .metropolis),
        CatalogCityItem(id: "memphis", name: "Memphis", countryCode: "US", landmark: "Graceland mansion portico and Beale Street sign", accent: "blues music record", archetype: .metropolis),
        CatalogCityItem(id: "oklahoma_city", name: "Oklahoma City", countryCode: "US", landmark: "Devon Energy Center glass tower", accent: "scissortail flycatcher bird", archetype: .metropolis),
        CatalogCityItem(id: "albuquerque", name: "Albuquerque", countryCode: "US", landmark: "Sandia Peak tramway tower", accent: "colorful hot air balloon", archetype: .metropolis),
        CatalogCityItem(id: "tucson", name: "Tucson", countryCode: "US", landmark: "Mission San Xavier del Bac white mission towers", accent: "desert prickly pear cactus", archetype: .metropolis),
        CatalogCityItem(id: "el_paso", name: "El Paso", countryCode: "US", landmark: "Franklin Mountains star on the mountain", accent: "desert yucca flower", archetype: .metropolis),
        CatalogCityItem(id: "san_juan", name: "San Juan", countryCode: "PR", landmark: "Castillo San Felipe del Morro stone fortress", accent: "colorful Old San Juan colonial building", archetype: .metropolis),
        CatalogCityItem(id: "anchorage", name: "Anchorage", countryCode: "US", landmark: "Denali snow mountain with Northern Lights glow", accent: "miniature grizzly bear", archetype: .metropolis),
        CatalogCityItem(id: "sacramento", name: "Sacramento", countryCode: "US", landmark: "Tower Bridge gold vertical lift bridge", accent: "California golden poppy flower", archetype: .metropolis),
        CatalogCityItem(id: "providence", name: "Providence", countryCode: "US", landmark: "Rhode Island State House marble dome", accent: "WaterFire brazier with flame", archetype: .metropolis),
        CatalogCityItem(id: "tokyo", name: "Tokyo", countryCode: "JP", landmark: "Tokyo Tower red and white spire", accent: "pink blooming sakura cherry blossom tree", archetype: .asian),
        CatalogCityItem(id: "kyoto", name: "Kyoto", countryCode: "JP", landmark: "Kinkaku-ji Golden Pavilion", accent: "vermilion Fushimi Inari torii gate", archetype: .asian),
        CatalogCityItem(id: "osaka", name: "Osaka", countryCode: "JP", landmark: "Osaka Castle main keep with gold leaf accents", accent: "miniature takoyaki stand", archetype: .asian),
        CatalogCityItem(id: "london", name: "London", countryCode: "GB", landmark: "Elizabeth Tower Big Ben clock tower", accent: "classic red double-decker bus", archetype: .european),
        CatalogCityItem(id: "edinburgh", name: "Edinburgh", countryCode: "GB", landmark: "Edinburgh Castle atop volcanic Castle Rock", accent: "Scottish tartan ribbon", archetype: .european),
        CatalogCityItem(id: "paris", name: "Paris", countryCode: "FR", landmark: "Eiffel Tower bronze lattice spire", accent: "green Parisian park tree", archetype: .european),
        CatalogCityItem(id: "nice", name: "Nice", countryCode: "FR", landmark: "Promenade des Anglais blue-roofed Negresco dome", accent: "Mediterranean palm tree", archetype: .european),
        CatalogCityItem(id: "beijing", name: "Beijing", countryCode: "CN", landmark: "Temple of Heaven Hall of Prayer for Good Harvests", accent: "imperial red wall and green cypress", archetype: .asian),
        CatalogCityItem(id: "shanghai", name: "Shanghai", countryCode: "CN", landmark: "Oriental Pearl Radio and TV Tower globes", accent: "The Bund classical granite facade", archetype: .asian),
        CatalogCityItem(id: "hong_kong", name: "Hong Kong", countryCode: "HK", landmark: "Bank of China Tower geometric glass prism", accent: "red-sailed Victoria Harbour junk boat", archetype: .asian),
        CatalogCityItem(id: "taipei", name: "Taipei", countryCode: "TW", landmark: "Taipei 101 bamboo pagoda skyscraper", accent: "steaming xiao long bao bamboo basket", archetype: .asian),
        CatalogCityItem(id: "singapore", name: "Singapore", countryCode: "SG", landmark: "Marina Bay Sands three towers and SkyPark", accent: "spouting Merlion statue", archetype: .asian),
        CatalogCityItem(id: "seoul", name: "Seoul", countryCode: "KR", landmark: "N Seoul Tower atop Namsan mountain", accent: "traditional Gyeongbokgung palace gate", archetype: .asian),
        CatalogCityItem(id: "bangkok", name: "Bangkok", countryCode: "TH", landmark: "Wat Arun Temple of Dawn porcelain spire", accent: "colorful tuk-tuk taxi", archetype: .asian),
        CatalogCityItem(id: "rome", name: "Rome", countryCode: "IT", landmark: "Colosseum amphitheatre travertine arches", accent: "vintage turquoise Vespa scooter", archetype: .european),
        CatalogCityItem(id: "venice", name: "Venice", countryCode: "IT", landmark: "St. Mark's Campanile belltower and Rialto Bridge", accent: "black Venetian gondola on blue canal", archetype: .european),
        CatalogCityItem(id: "florence", name: "Florence", countryCode: "IT", landmark: "Santa Maria del Fiore Duomo terracotta dome", accent: "Ponte Vecchio medieval bridge", archetype: .european),
        CatalogCityItem(id: "milan", name: "Milan", countryCode: "IT", landmark: "Milan Duomo Gothic marble spires", accent: "Galleria Vittorio Emanuele glass dome", archetype: .european),
        CatalogCityItem(id: "barcelona", name: "Barcelona", countryCode: "ES", landmark: "Sagrada Família towering Nativity spires", accent: "Park Güell colorful mosaic lizard", archetype: .european),
        CatalogCityItem(id: "madrid", name: "Madrid", countryCode: "ES", landmark: "Puerta de Alcalá neoclassical granite gate", accent: "Plaza Mayor royal bronze statue", archetype: .european),
        CatalogCityItem(id: "amsterdam", name: "Amsterdam", countryCode: "NL", landmark: "Gable-roof canal houses and Dutch windmill", accent: "classic Dutch city bicycle", archetype: .european),
        CatalogCityItem(id: "berlin", name: "Berlin", countryCode: "DE", landmark: "Brandenburg Gate with Quadriga chariot", accent: "Berliner Fernsehturm TV tower", archetype: .european),
        CatalogCityItem(id: "munich", name: "Munich", countryCode: "DE", landmark: "Frauenkirche twin onion-domed towers", accent: "Bavarian pretzel", archetype: .european),
        CatalogCityItem(id: "vienna", name: "Vienna", countryCode: "AT", landmark: "St. Stephen's Cathedral mosaic tile roof", accent: "Riesenrad Giant Ferris Wheel", archetype: .european),
        CatalogCityItem(id: "prague", name: "Prague", countryCode: "CZ", landmark: "Charles Bridge Gothic stone tower and Prague Castle", accent: "Astronomical Clock dial", archetype: .european),
        CatalogCityItem(id: "budapest", name: "Budapest", countryCode: "HU", landmark: "Hungarian Parliament Building neo-Gothic dome and spires", accent: "Széchenyi Chain Bridge lion statue", archetype: .european),
        CatalogCityItem(id: "zurich", name: "Zurich", countryCode: "CH", landmark: "Grossmünster twin Romanesque towers over Lake Zurich", accent: "Swiss railway clock", archetype: .alpine),
        CatalogCityItem(id: "geneva", name: "Geneva", countryCode: "CH", landmark: "Jet d'Eau towering water fountain plume", accent: "L'horloge fleurie flower clock", archetype: .coastal),
        CatalogCityItem(id: "sydney", name: "Sydney", countryCode: "AU", landmark: "Sydney Opera House white sail shells", accent: "Sydney Harbour Bridge steel arch", archetype: .coastal),
        CatalogCityItem(id: "melbourne", name: "Melbourne", countryCode: "AU", landmark: "Flinders Street railway station yellow dome", accent: "vintage green W-class tram", archetype: .coastal),
        CatalogCityItem(id: "auckland", name: "Auckland", countryCode: "NZ", landmark: "Sky Tower needle spire overlooking Waitematā Harbour", accent: "silver fern leaf", archetype: .coastal),
        CatalogCityItem(id: "dubai", name: "Dubai", countryCode: "AE", landmark: "Burj Khalifa glass tiered skyscraper", accent: "Burj Al Arab sail hotel", archetype: .desert),
        CatalogCityItem(id: "doha", name: "Doha", countryCode: "QA", landmark: "Museum of Islamic Art geometric limestone blocks", accent: "traditional wooden dhow boat", archetype: .desert),
        CatalogCityItem(id: "cairo", name: "Cairo", countryCode: "EG", landmark: "Great Pyramid of Giza limestone blocks", accent: "Great Sphinx stone head", archetype: .desert),
        CatalogCityItem(id: "cape_town", name: "Cape Town", countryCode: "ZA", landmark: "Table Mountain flat plateau sandstone massif", accent: "colorful Bo-Kaap painted cottage", archetype: .coastal),
        CatalogCityItem(id: "toronto", name: "Toronto", countryCode: "CA", landmark: "CN Tower needle spire and observation pod", accent: "red maple leaf", archetype: .metropolis),
        CatalogCityItem(id: "vancouver", name: "Vancouver", countryCode: "CA", landmark: "Canada Place white fiberglass sail roof", accent: "coastal mountain pine forest", archetype: .coastal),
        CatalogCityItem(id: "montreal", name: "Montreal", countryCode: "CA", landmark: "Notre-Dame Basilica twin Gothic revival towers", accent: "Mount Royal cross", archetype: .metropolis),
        CatalogCityItem(id: "mexico_city", name: "Mexico City", countryCode: "MX", landmark: "Angel of Independence golden winged statue", accent: "Palacio de Bellas Artes art nouveau dome", archetype: .metropolis),
        CatalogCityItem(id: "rio_de_janeiro", name: "Rio de Janeiro", countryCode: "BR", landmark: "Christ the Redeemer statue atop Corcovado", accent: "Sugarloaf Mountain cable car", archetype: .coastal),
        CatalogCityItem(id: "sao_paulo", name: "São Paulo", countryCode: "BR", landmark: "Octávio Frias de Oliveira X-shaped cable-stayed bridge", accent: "Paulista Avenue modern high-rise", archetype: .metropolis),
        CatalogCityItem(id: "buenos_aires", name: "Buenos Aires", countryCode: "AR", landmark: "Obelisco de Buenos Aires white stone obelisk", accent: "colorful La Boca Caminito building", archetype: .metropolis),
        CatalogCityItem(id: "santiago", name: "Santiago", countryCode: "CL", landmark: "Gran Torre Santiago glass skyscraper", accent: "Andes snow mountain range", archetype: .metropolis),
        CatalogCityItem(id: "lima", name: "Lima", countryCode: "PE", landmark: "Lima Cathedral yellow baroque towers", accent: "Miraflores coastal ocean cliff", archetype: .metropolis),
        CatalogCityItem(id: "dublin", name: "Dublin", countryCode: "IE", landmark: "Custom House neoclassical riverfront dome and Ha'penny Bridge", accent: "green shamrock clover", archetype: .european),
        CatalogCityItem(id: "lisbon", name: "Lisbon", countryCode: "PT", landmark: "Belém Tower Manueline fortress on blue water", accent: "vintage yellow Tram 28", archetype: .european),
        CatalogCityItem(id: "athens", name: "Athens", countryCode: "GR", landmark: "Parthenon temple Doric marble columns atop Acropolis", accent: "ancient olive branch", archetype: .metropolis),
        CatalogCityItem(id: "istanbul", name: "Istanbul", countryCode: "TR", landmark: "Hagia Sophia massive dome and minarets", accent: "Bosphorus Bridge blue strait", archetype: .metropolis),
        CatalogCityItem(id: "copenhagen", name: "Copenhagen", countryCode: "DK", landmark: "Nyhavn colorful 17th-century canal townhouses", accent: "The Little Mermaid bronze statue on rock", archetype: .european),
        CatalogCityItem(id: "stockholm", name: "Stockholm", countryCode: "SE", landmark: "Stockholm City Hall brick tower with Three Crowns", accent: "Gamla Stan ochre facade", archetype: .european),
        CatalogCityItem(id: "helsinki", name: "Helsinki", countryCode: "FI", landmark: "Helsinki Cathedral white neoclassical dome and Corinthian columns", accent: "Suomenlinna sea fortress cannon", archetype: .european),
        CatalogCityItem(id: "oslo", name: "Oslo", countryCode: "NO", landmark: "Oslo Opera House white angled marble roof sloping into fjord", accent: "Viking longship wooden prow", archetype: .european)
    ]
}

#Preview {
    NavigationStack {
        CityEmblemGalleryView()
    }
}
