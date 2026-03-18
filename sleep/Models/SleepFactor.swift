//
//  SleepFactor.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - FactorType

enum FactorType: String, Codable, CaseIterable, Identifiable {
    case caffeine
    case alcohol
    case exercise
    case screenTime
    case lateMeal
    case stress
    case medication
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .caffeine: "Caffeine"
        case .alcohol: "Alcohol"
        case .exercise: "Exercise"
        case .screenTime: "Screen Time"
        case .lateMeal: "Late Meal"
        case .stress: "Stress"
        case .medication: "Medication"
        case .custom: "Custom"
        }
    }

    var icon: String {
        switch self {
        case .caffeine: "cup.and.saucer.fill"
        case .alcohol: "wineglass.fill"
        case .exercise: "figure.run"
        case .screenTime: "iphone"
        case .lateMeal: "fork.knife"
        case .stress: "brain.head.profile.fill"
        case .medication: "pills.fill"
        case .custom: "tag.fill"
        }
    }

    var color: Color {
        switch self {
        case .caffeine: .brown
        case .alcohol: .purple
        case .exercise: .green
        case .screenTime: .blue
        case .lateMeal: .orange
        case .stress: .red
        case .medication: .teal
        case .custom: .gray
        }
    }
}

// MARK: - SleepFactor

@Model
final class SleepFactor {
    var date: Date
    var factorType: String   // FactorType.rawValue
    var customLabel: String  // For custom factors
    var intensity: Int       // 1-5 scale

    var type: FactorType {
        FactorType(rawValue: factorType) ?? .custom
    }

    var displayLabel: String {
        type == .custom ? customLabel : type.label
    }

    init(date: Date, type: FactorType, customLabel: String = "", intensity: Int = 3) {
        self.date = date
        self.factorType = type.rawValue
        self.customLabel = customLabel
        self.intensity = min(5, max(1, intensity))
    }
}

// MARK: - MorningMood

enum MorningMood: Int, Codable, CaseIterable, Identifiable {
    case terrible = 1
    case bad = 2
    case okay = 3
    case good = 4
    case great = 5

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .terrible: "😫"
        case .bad: "😴"
        case .okay: "😐"
        case .good: "😊"
        case .great: "🤩"
        }
    }

    var label: String {
        switch self {
        case .terrible: "Terrible"
        case .bad: "Tired"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }
}

// MARK: - SoundItem

struct SoundItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let category: SoundCategory
    let fileName: String       // local audio file name
    let isPremium: Bool

    enum SoundCategory: String, CaseIterable, Identifiable {
        case nature = "Nature"
        case whiteNoise = "White Noise"
        case ambient = "Ambient"
        case instrumental = "Instrumental"
        case meditation = "Meditation"
        case stories = "Stories"
        case asmr = "ASMR"

        var id: String { rawValue }
    }
}

// MARK: - Sound Library

enum SoundLibrary {
    static let all: [SoundItem] = [
        // Nature
        SoundItem(id: "rain", name: "Rain", icon: "cloud.rain.fill", category: .nature, fileName: "rain", isPremium: false),
        SoundItem(id: "ocean", name: "Ocean Waves", icon: "water.waves", category: .nature, fileName: "ocean", isPremium: false),
        SoundItem(id: "thunder", name: "Thunderstorm", icon: "cloud.bolt.rain.fill", category: .nature, fileName: "thunder", isPremium: false),
        SoundItem(id: "forest", name: "Forest", icon: "tree.fill", category: .nature, fileName: "forest", isPremium: false),
        SoundItem(id: "wind", name: "Wind", icon: "wind", category: .nature, fileName: "wind", isPremium: true),
        SoundItem(id: "creek", name: "Creek", icon: "drop.fill", category: .nature, fileName: "creek", isPremium: true),
        SoundItem(id: "birds", name: "Morning Birds", icon: "bird.fill", category: .nature, fileName: "birds", isPremium: true),
        SoundItem(id: "campfire", name: "Campfire", icon: "flame.fill", category: .nature, fileName: "campfire", isPremium: true),

        // White Noise
        SoundItem(id: "white", name: "White Noise", icon: "waveform", category: .whiteNoise, fileName: "white", isPremium: false),
        SoundItem(id: "pink", name: "Pink Noise", icon: "waveform", category: .whiteNoise, fileName: "pink", isPremium: false),
        SoundItem(id: "brown", name: "Brown Noise", icon: "waveform", category: .whiteNoise, fileName: "brown", isPremium: false),
        SoundItem(id: "fan", name: "Fan", icon: "fan.fill", category: .whiteNoise, fileName: "fan", isPremium: false),
        SoundItem(id: "ac", name: "Air Conditioner", icon: "air.conditioner.horizontal.fill", category: .whiteNoise, fileName: "ac", isPremium: true),

        // Ambient
        SoundItem(id: "city", name: "City Night", icon: "building.2.fill", category: .ambient, fileName: "city", isPremium: true),
        SoundItem(id: "train", name: "Train", icon: "tram.fill", category: .ambient, fileName: "train", isPremium: true),
        SoundItem(id: "cafe", name: "Cafe", icon: "mug.fill", category: .ambient, fileName: "cafe", isPremium: true),

        // Instrumental
        SoundItem(id: "piano", name: "Soft Piano", icon: "pianokeys", category: .instrumental, fileName: "piano", isPremium: true),
        SoundItem(id: "guitar", name: "Gentle Guitar", icon: "guitars.fill", category: .instrumental, fileName: "guitar", isPremium: true),

        // MARK: Nature (expanded)
        SoundItem(id: "gentle_rain", name: "Gentle Rain", icon: "cloud.drizzle.fill", category: .nature, fileName: "gentle_rain", isPremium: false),
        SoundItem(id: "heavy_rain", name: "Heavy Rain", icon: "cloud.heavyrain.fill", category: .nature, fileName: "heavy_rain", isPremium: false),
        SoundItem(id: "rain_on_tent", name: "Rain on Tent", icon: "tent.fill", category: .nature, fileName: "rain_on_tent", isPremium: true),
        SoundItem(id: "rain_on_window", name: "Rain on Window", icon: "window.casement", category: .nature, fileName: "rain_on_window", isPremium: true),
        SoundItem(id: "waterfall", name: "Waterfall", icon: "water.waves", category: .nature, fileName: "waterfall", isPremium: false),
        SoundItem(id: "river", name: "River", icon: "water.waves", category: .nature, fileName: "river", isPremium: false),
        SoundItem(id: "lake_lapping", name: "Lake Lapping", icon: "water.waves", category: .nature, fileName: "lake_lapping", isPremium: true),
        SoundItem(id: "tropical_rain", name: "Tropical Rain", icon: "cloud.rain.fill", category: .nature, fileName: "tropical_rain", isPremium: true),
        SoundItem(id: "spring_rain", name: "Spring Rain", icon: "cloud.rain.fill", category: .nature, fileName: "spring_rain", isPremium: false),
        SoundItem(id: "morning_dew", name: "Morning Dew", icon: "drop.fill", category: .nature, fileName: "morning_dew", isPremium: true),
        SoundItem(id: "nighttime_forest", name: "Nighttime Forest", icon: "tree.fill", category: .nature, fileName: "nighttime_forest", isPremium: false),
        SoundItem(id: "tropical_forest", name: "Tropical Forest", icon: "leaf.fill", category: .nature, fileName: "tropical_forest", isPremium: true),
        SoundItem(id: "bamboo_forest", name: "Bamboo Forest", icon: "leaf.fill", category: .nature, fileName: "bamboo_forest", isPremium: true),
        SoundItem(id: "autumn_leaves", name: "Autumn Leaves", icon: "leaf.fill", category: .nature, fileName: "autumn_leaves", isPremium: false),
        SoundItem(id: "meadow", name: "Meadow", icon: "leaf.fill", category: .nature, fileName: "meadow", isPremium: false),
        SoundItem(id: "monsoon", name: "Monsoon", icon: "cloud.heavyrain.fill", category: .nature, fileName: "monsoon", isPremium: true),
        SoundItem(id: "distant_thunder", name: "Distant Thunder", icon: "cloud.bolt.fill", category: .nature, fileName: "distant_thunder", isPremium: false),
        SoundItem(id: "rolling_thunder", name: "Rolling Thunder", icon: "cloud.bolt.rain.fill", category: .nature, fileName: "rolling_thunder", isPremium: true),
        SoundItem(id: "gentle_breeze", name: "Gentle Breeze", icon: "wind", category: .nature, fileName: "gentle_breeze", isPremium: false),
        SoundItem(id: "mountain_wind", name: "Mountain Wind", icon: "mountain.2.fill", category: .nature, fileName: "mountain_wind", isPremium: true),
        SoundItem(id: "desert_wind", name: "Desert Wind", icon: "sun.max.fill", category: .nature, fileName: "desert_wind", isPremium: true),
        SoundItem(id: "snowfall", name: "Snowfall", icon: "snowflake", category: .nature, fileName: "snowfall", isPremium: false),
        SoundItem(id: "arctic_wind", name: "Arctic Wind", icon: "snowflake", category: .nature, fileName: "arctic_wind", isPremium: true),
        SoundItem(id: "beach_sunset", name: "Beach Sunset", icon: "sun.horizon.fill", category: .nature, fileName: "beach_sunset", isPremium: false),
        SoundItem(id: "tide_pools", name: "Tide Pools", icon: "drop.fill", category: .nature, fileName: "tide_pools", isPremium: true),
        SoundItem(id: "coral_reef", name: "Coral Reef", icon: "water.waves", category: .nature, fileName: "coral_reef", isPremium: true),
        SoundItem(id: "whale_songs", name: "Whale Songs", icon: "waveform.path", category: .nature, fileName: "whale_songs", isPremium: true),
        SoundItem(id: "dolphin_sounds", name: "Dolphin Sounds", icon: "waveform.path", category: .nature, fileName: "dolphin_sounds", isPremium: true),
        SoundItem(id: "rainforest", name: "Rainforest", icon: "leaf.fill", category: .nature, fileName: "rainforest", isPremium: false),

        // MARK: White Noise (expanded)
        SoundItem(id: "gray_noise", name: "Gray Noise", icon: "waveform", category: .whiteNoise, fileName: "gray_noise", isPremium: false),
        SoundItem(id: "blue_noise", name: "Blue Noise", icon: "waveform", category: .whiteNoise, fileName: "blue_noise", isPremium: false),
        SoundItem(id: "violet_noise", name: "Violet Noise", icon: "waveform", category: .whiteNoise, fileName: "violet_noise", isPremium: true),
        SoundItem(id: "velvet_noise", name: "Velvet Noise", icon: "waveform", category: .whiteNoise, fileName: "velvet_noise", isPremium: true),
        SoundItem(id: "static", name: "Static", icon: "waveform.path", category: .whiteNoise, fileName: "static", isPremium: false),
        SoundItem(id: "dryer", name: "Dryer", icon: "washer.fill", category: .whiteNoise, fileName: "dryer", isPremium: true),
        SoundItem(id: "washing_machine", name: "Washing Machine", icon: "washer.fill", category: .whiteNoise, fileName: "washing_machine", isPremium: true),
        SoundItem(id: "vacuum", name: "Vacuum", icon: "waveform.path", category: .whiteNoise, fileName: "vacuum", isPremium: false),
        SoundItem(id: "hair_dryer", name: "Hair Dryer", icon: "wind", category: .whiteNoise, fileName: "hair_dryer", isPremium: false),
        SoundItem(id: "airplane_cabin", name: "Airplane Cabin", icon: "airplane", category: .whiteNoise, fileName: "airplane_cabin", isPremium: true),
        SoundItem(id: "car_engine", name: "Car Engine", icon: "car.fill", category: .whiteNoise, fileName: "car_engine", isPremium: false),
        SoundItem(id: "bus_ride", name: "Bus Ride", icon: "bus.fill", category: .whiteNoise, fileName: "bus_ride", isPremium: true),
        SoundItem(id: "subway", name: "Subway", icon: "tram.fill", category: .whiteNoise, fileName: "subway", isPremium: true),
        SoundItem(id: "noise_machine", name: "Noise Machine", icon: "waveform", category: .whiteNoise, fileName: "noise_machine", isPremium: false),
        SoundItem(id: "deep_hum", name: "Deep Hum", icon: "waveform.path", category: .whiteNoise, fileName: "deep_hum", isPremium: true),

        // MARK: Ambient (expanded)
        SoundItem(id: "library", name: "Library", icon: "books.vertical.fill", category: .ambient, fileName: "library", isPremium: false),
        SoundItem(id: "bookstore", name: "Bookstore", icon: "book.fill", category: .ambient, fileName: "bookstore", isPremium: true),
        SoundItem(id: "coffee_shop", name: "Coffee Shop", icon: "mug.fill", category: .ambient, fileName: "coffee_shop", isPremium: false),
        SoundItem(id: "rainy_street", name: "Rainy Street", icon: "cloud.rain.fill", category: .ambient, fileName: "rainy_street", isPremium: true),
        SoundItem(id: "cozy_cabin", name: "Cozy Cabin", icon: "house.fill", category: .ambient, fileName: "cozy_cabin", isPremium: false),
        SoundItem(id: "fireplace_crackling", name: "Fireplace Crackling", icon: "flame.fill", category: .ambient, fileName: "fireplace_crackling", isPremium: false),
        SoundItem(id: "japanese_garden", name: "Japanese Garden", icon: "leaf.fill", category: .ambient, fileName: "japanese_garden", isPremium: true),
        SoundItem(id: "zen_temple", name: "Zen Temple", icon: "building.columns.fill", category: .ambient, fileName: "zen_temple", isPremium: true),
        SoundItem(id: "tibetan_singing_bowls", name: "Tibetan Singing Bowls", icon: "bell.fill", category: .ambient, fileName: "tibetan_singing_bowls", isPremium: true),
        SoundItem(id: "wind_chimes", name: "Wind Chimes", icon: "wind", category: .ambient, fileName: "wind_chimes", isPremium: false),
        SoundItem(id: "clock_ticking", name: "Clock Ticking", icon: "clock.fill", category: .ambient, fileName: "clock_ticking", isPremium: false),
        SoundItem(id: "vintage_radio_static", name: "Vintage Radio Static", icon: "radio.fill", category: .ambient, fileName: "vintage_radio_static", isPremium: true),
        SoundItem(id: "space_station", name: "Space Station", icon: "sparkles", category: .ambient, fileName: "space_station", isPremium: true),
        SoundItem(id: "underwater", name: "Underwater", icon: "water.waves", category: .ambient, fileName: "underwater", isPremium: true),
        SoundItem(id: "countryside", name: "Countryside", icon: "leaf.fill", category: .ambient, fileName: "countryside", isPremium: false),
        SoundItem(id: "barn", name: "Barn", icon: "house.fill", category: .ambient, fileName: "barn", isPremium: true),
        SoundItem(id: "harbor", name: "Harbor", icon: "ferry.fill", category: .ambient, fileName: "harbor", isPremium: false),
        SoundItem(id: "marketplace", name: "Marketplace", icon: "cart.fill", category: .ambient, fileName: "marketplace", isPremium: true),
        SoundItem(id: "night_highway", name: "Night Highway", icon: "road.lanes", category: .ambient, fileName: "night_highway", isPremium: true),
        SoundItem(id: "laundry_room", name: "Laundry Room", icon: "washer.fill", category: .ambient, fileName: "laundry_room", isPremium: false),
        SoundItem(id: "workshop", name: "Workshop", icon: "wrench.and.screwdriver.fill", category: .ambient, fileName: "workshop", isPremium: true),
        SoundItem(id: "art_studio", name: "Art Studio", icon: "paintpalette.fill", category: .ambient, fileName: "art_studio", isPremium: true),
        SoundItem(id: "yoga_studio", name: "Yoga Studio", icon: "figure.yoga", category: .ambient, fileName: "yoga_studio", isPremium: false),
        SoundItem(id: "sauna", name: "Sauna", icon: "humidity.fill", category: .ambient, fileName: "sauna", isPremium: true),
        SoundItem(id: "hot_tub", name: "Hot Tub", icon: "bathtub.fill", category: .ambient, fileName: "hot_tub", isPremium: true),

        // MARK: Instrumental (expanded)
        SoundItem(id: "harp", name: "Harp", icon: "waveform.path", category: .instrumental, fileName: "harp", isPremium: false),
        SoundItem(id: "flute", name: "Flute", icon: "waveform.path", category: .instrumental, fileName: "flute", isPremium: true),
        SoundItem(id: "cello", name: "Cello", icon: "waveform.path", category: .instrumental, fileName: "cello", isPremium: false),
        SoundItem(id: "violin", name: "Violin", icon: "waveform.path", category: .instrumental, fileName: "violin", isPremium: true),
        SoundItem(id: "acoustic_guitar", name: "Acoustic Guitar", icon: "guitars.fill", category: .instrumental, fileName: "acoustic_guitar", isPremium: false),
        SoundItem(id: "classical_guitar", name: "Classical Guitar", icon: "guitars.fill", category: .instrumental, fileName: "classical_guitar", isPremium: true),
        SoundItem(id: "ukulele", name: "Ukulele", icon: "guitars.fill", category: .instrumental, fileName: "ukulele", isPremium: false),
        SoundItem(id: "kalimba", name: "Kalimba", icon: "pianokeys", category: .instrumental, fileName: "kalimba", isPremium: true),
        SoundItem(id: "music_box", name: "Music Box", icon: "music.note", category: .instrumental, fileName: "music_box", isPremium: false),
        SoundItem(id: "hang_drum", name: "Hang Drum", icon: "circle.circle.fill", category: .instrumental, fileName: "hang_drum", isPremium: true),
        SoundItem(id: "steel_drums", name: "Steel Drums", icon: "circle.circle.fill", category: .instrumental, fileName: "steel_drums", isPremium: true),
        SoundItem(id: "chimes", name: "Chimes", icon: "bell.fill", category: .instrumental, fileName: "chimes", isPremium: false),
        SoundItem(id: "lullaby", name: "Lullaby", icon: "music.note", category: .instrumental, fileName: "lullaby", isPremium: false),
        SoundItem(id: "jazz_piano", name: "Jazz Piano", icon: "pianokeys", category: .instrumental, fileName: "jazz_piano", isPremium: true),
        SoundItem(id: "lofi_beats", name: "Lo-fi Beats", icon: "headphones", category: .instrumental, fileName: "lofi_beats", isPremium: true),
        SoundItem(id: "ambient_synth", name: "Ambient Synth", icon: "waveform.path", category: .instrumental, fileName: "ambient_synth", isPremium: true),
        SoundItem(id: "binaural_432hz", name: "Binaural Beats 432Hz", icon: "headphones", category: .instrumental, fileName: "binaural_432hz", isPremium: true),
        SoundItem(id: "binaural_delta", name: "Binaural Beats Delta", icon: "headphones", category: .instrumental, fileName: "binaural_delta", isPremium: true),
        SoundItem(id: "solfeggio_frequencies", name: "Solfeggio Frequencies", icon: "waveform.path", category: .instrumental, fileName: "solfeggio_frequencies", isPremium: true),
        SoundItem(id: "drone_music", name: "Drone Music", icon: "waveform.path", category: .instrumental, fileName: "drone_music", isPremium: false),

        // MARK: Meditation
        SoundItem(id: "body_scan", name: "Body Scan", icon: "figure.stand", category: .meditation, fileName: "body_scan", isPremium: true),
        SoundItem(id: "progressive_relaxation", name: "Progressive Relaxation", icon: "figure.cooldown", category: .meditation, fileName: "progressive_relaxation", isPremium: true),
        SoundItem(id: "breathing_478", name: "Breathing Exercise 4-7-8", icon: "lungs.fill", category: .meditation, fileName: "breathing_478", isPremium: true),
        SoundItem(id: "box_breathing", name: "Box Breathing", icon: "square", category: .meditation, fileName: "box_breathing", isPremium: true),
        SoundItem(id: "deep_breathing", name: "Deep Breathing", icon: "lungs.fill", category: .meditation, fileName: "deep_breathing", isPremium: true),
        SoundItem(id: "loving_kindness", name: "Loving Kindness", icon: "heart.fill", category: .meditation, fileName: "loving_kindness", isPremium: true),
        SoundItem(id: "gratitude_meditation", name: "Gratitude Meditation", icon: "hands.sparkles.fill", category: .meditation, fileName: "gratitude_meditation", isPremium: true),
        SoundItem(id: "mindfulness", name: "Mindfulness", icon: "brain.head.profile.fill", category: .meditation, fileName: "mindfulness", isPremium: true),
        SoundItem(id: "sleep_yoga_nidra", name: "Sleep Yoga Nidra", icon: "figure.yoga", category: .meditation, fileName: "sleep_yoga_nidra", isPremium: true),
        SoundItem(id: "visualization_beach", name: "Visualization Beach", icon: "sun.horizon.fill", category: .meditation, fileName: "visualization_beach", isPremium: true),
        SoundItem(id: "visualization_forest", name: "Visualization Forest", icon: "tree.fill", category: .meditation, fileName: "visualization_forest", isPremium: true),
        SoundItem(id: "visualization_mountain", name: "Visualization Mountain", icon: "mountain.2.fill", category: .meditation, fileName: "visualization_mountain", isPremium: true),
        SoundItem(id: "visualization_stars", name: "Visualization Stars", icon: "star.fill", category: .meditation, fileName: "visualization_stars", isPremium: true),
        SoundItem(id: "counting_down", name: "Counting Down", icon: "number", category: .meditation, fileName: "counting_down", isPremium: true),
        SoundItem(id: "muscle_tension_release", name: "Muscle Tension Release", icon: "figure.strengthtraining.traditional", category: .meditation, fileName: "muscle_tension_release", isPremium: true),
        SoundItem(id: "autogenic_training", name: "Autogenic Training", icon: "brain.fill", category: .meditation, fileName: "autogenic_training", isPremium: true),
        SoundItem(id: "chakra_balancing", name: "Chakra Balancing", icon: "circle.hexagongrid.fill", category: .meditation, fileName: "chakra_balancing", isPremium: true),
        SoundItem(id: "third_eye_meditation", name: "Third Eye Meditation", icon: "eye.fill", category: .meditation, fileName: "third_eye_meditation", isPremium: true),
        SoundItem(id: "sound_bath", name: "Sound Bath", icon: "waveform.path", category: .meditation, fileName: "sound_bath", isPremium: true),
        SoundItem(id: "gong_meditation", name: "Gong Meditation", icon: "bell.fill", category: .meditation, fileName: "gong_meditation", isPremium: true),
        SoundItem(id: "tibetan_bowl_session", name: "Tibetan Bowl Session", icon: "bell.fill", category: .meditation, fileName: "tibetan_bowl_session", isPremium: true),
        SoundItem(id: "crystal_bowl_session", name: "Crystal Bowl Session", icon: "sparkles", category: .meditation, fileName: "crystal_bowl_session", isPremium: true),
        SoundItem(id: "mantra_om", name: "Mantra OM", icon: "waveform.path", category: .meditation, fileName: "mantra_om", isPremium: true),
        SoundItem(id: "guided_imagery", name: "Guided Imagery", icon: "eye.fill", category: .meditation, fileName: "guided_imagery", isPremium: true),
        SoundItem(id: "sleep_hypnosis", name: "Sleep Hypnosis", icon: "sparkles", category: .meditation, fileName: "sleep_hypnosis", isPremium: true),

        // MARK: Stories
        SoundItem(id: "the_enchanted_garden", name: "The Enchanted Garden", icon: "book.fill", category: .stories, fileName: "the_enchanted_garden", isPremium: true),
        SoundItem(id: "moonlit_voyage", name: "Moonlit Voyage", icon: "book.fill", category: .stories, fileName: "moonlit_voyage", isPremium: true),
        SoundItem(id: "lighthouse_keeper", name: "Lighthouse Keeper", icon: "book.fill", category: .stories, fileName: "lighthouse_keeper", isPremium: true),
        SoundItem(id: "starlight_express", name: "Starlight Express", icon: "book.fill", category: .stories, fileName: "starlight_express", isPremium: true),
        SoundItem(id: "whispering_woods", name: "Whispering Woods", icon: "book.fill", category: .stories, fileName: "whispering_woods", isPremium: true),
        SoundItem(id: "cloud_kingdom", name: "Cloud Kingdom", icon: "book.fill", category: .stories, fileName: "cloud_kingdom", isPremium: true),
        SoundItem(id: "gentle_river_journey", name: "Gentle River Journey", icon: "book.fill", category: .stories, fileName: "gentle_river_journey", isPremium: true),
        SoundItem(id: "mountain_cabin", name: "Mountain Cabin", icon: "book.fill", category: .stories, fileName: "mountain_cabin", isPremium: true),
        SoundItem(id: "desert_caravan", name: "Desert Caravan", icon: "book.fill", category: .stories, fileName: "desert_caravan", isPremium: true),
        SoundItem(id: "underwater_palace", name: "Underwater Palace", icon: "book.fill", category: .stories, fileName: "underwater_palace", isPremium: true),
        SoundItem(id: "floating_islands", name: "Floating Islands", icon: "book.fill", category: .stories, fileName: "floating_islands", isPremium: true),
        SoundItem(id: "ancient_library", name: "Ancient Library", icon: "book.fill", category: .stories, fileName: "ancient_library", isPremium: true),
        SoundItem(id: "silk_road", name: "Silk Road", icon: "book.fill", category: .stories, fileName: "silk_road", isPremium: true),
        SoundItem(id: "northern_lights", name: "Northern Lights", icon: "book.fill", category: .stories, fileName: "northern_lights", isPremium: true),
        SoundItem(id: "cherry_blossom_festival", name: "Cherry Blossom Festival", icon: "book.fill", category: .stories, fileName: "cherry_blossom_festival", isPremium: true),
        SoundItem(id: "venice_at_night", name: "Venice at Night", icon: "book.fill", category: .stories, fileName: "venice_at_night", isPremium: true),
        SoundItem(id: "paris_in_rain", name: "Paris in Rain", icon: "book.fill", category: .stories, fileName: "paris_in_rain", isPremium: true),
        SoundItem(id: "london_fog", name: "London Fog", icon: "book.fill", category: .stories, fileName: "london_fog", isPremium: true),
        SoundItem(id: "tokyo_midnight", name: "Tokyo Midnight", icon: "book.fill", category: .stories, fileName: "tokyo_midnight", isPremium: true),
        SoundItem(id: "scottish_highlands", name: "Scottish Highlands", icon: "book.fill", category: .stories, fileName: "scottish_highlands", isPremium: true),
        SoundItem(id: "norwegian_fjords", name: "Norwegian Fjords", icon: "book.fill", category: .stories, fileName: "norwegian_fjords", isPremium: true),
        SoundItem(id: "australian_outback", name: "Australian Outback", icon: "book.fill", category: .stories, fileName: "australian_outback", isPremium: true),
        SoundItem(id: "amazon_rainforest", name: "Amazon Rainforest", icon: "book.fill", category: .stories, fileName: "amazon_rainforest", isPremium: true),
        SoundItem(id: "arctic_explorer", name: "Arctic Explorer", icon: "book.fill", category: .stories, fileName: "arctic_explorer", isPremium: true),
        SoundItem(id: "space_odyssey", name: "Space Odyssey", icon: "book.fill", category: .stories, fileName: "space_odyssey", isPremium: true),

        // MARK: ASMR
        SoundItem(id: "page_turning", name: "Page Turning", icon: "hand.raised.fingers.spread.fill", category: .asmr, fileName: "page_turning", isPremium: true),
        SoundItem(id: "keyboard_typing", name: "Keyboard Typing", icon: "keyboard.fill", category: .asmr, fileName: "keyboard_typing", isPremium: true),
        SoundItem(id: "writing_sounds", name: "Writing Sounds", icon: "pencil", category: .asmr, fileName: "writing_sounds", isPremium: true),
        SoundItem(id: "brush_strokes", name: "Brush Strokes", icon: "paintbrush.fill", category: .asmr, fileName: "brush_strokes", isPremium: true),
        SoundItem(id: "tapping", name: "Tapping", icon: "hand.tap.fill", category: .asmr, fileName: "tapping", isPremium: true),
        SoundItem(id: "scratching", name: "Scratching", icon: "hand.raised.fingers.spread.fill", category: .asmr, fileName: "scratching", isPremium: true),
        SoundItem(id: "whispering", name: "Whispering", icon: "mouth.fill", category: .asmr, fileName: "whispering", isPremium: true),
        SoundItem(id: "crinkle_sounds", name: "Crinkle Sounds", icon: "hand.raised.fingers.spread.fill", category: .asmr, fileName: "crinkle_sounds", isPremium: true),
        SoundItem(id: "water_drops", name: "Water Drops", icon: "drop.fill", category: .asmr, fileName: "water_drops", isPremium: true),
        SoundItem(id: "sand_pouring", name: "Sand Pouring", icon: "hourglass", category: .asmr, fileName: "sand_pouring", isPremium: true),
        SoundItem(id: "fabric_sounds", name: "Fabric Sounds", icon: "hand.raised.fingers.spread.fill", category: .asmr, fileName: "fabric_sounds", isPremium: true),
        SoundItem(id: "hair_brushing", name: "Hair Brushing", icon: "paintbrush.fill", category: .asmr, fileName: "hair_brushing", isPremium: true),
        SoundItem(id: "bubble_wrap", name: "Bubble Wrap", icon: "circle.grid.3x3.fill", category: .asmr, fileName: "bubble_wrap", isPremium: true),
        SoundItem(id: "soap_cutting", name: "Soap Cutting", icon: "scissors", category: .asmr, fileName: "soap_cutting", isPremium: true),
        SoundItem(id: "slime", name: "Slime", icon: "drop.fill", category: .asmr, fileName: "slime", isPremium: true),
        SoundItem(id: "wood_carving", name: "Wood Carving", icon: "hammer.fill", category: .asmr, fileName: "wood_carving", isPremium: true),
        SoundItem(id: "glass_tapping", name: "Glass Tapping", icon: "hand.tap.fill", category: .asmr, fileName: "glass_tapping", isPremium: true),
        SoundItem(id: "metal_sounds", name: "Metal Sounds", icon: "waveform.path", category: .asmr, fileName: "metal_sounds", isPremium: true),
        SoundItem(id: "nature_asmr", name: "Nature ASMR", icon: "leaf.fill", category: .asmr, fileName: "nature_asmr", isPremium: true),
        SoundItem(id: "rain_asmr", name: "Rain ASMR", icon: "cloud.rain.fill", category: .asmr, fileName: "rain_asmr", isPremium: true),

        // MARK: Additional Nature
        SoundItem(id: "misty_morning", name: "Misty Morning", icon: "cloud.fog.fill", category: .nature, fileName: "misty_morning", isPremium: true),
        SoundItem(id: "pine_forest", name: "Pine Forest", icon: "tree.fill", category: .nature, fileName: "pine_forest", isPremium: false),
        SoundItem(id: "ice_cracking", name: "Ice Cracking", icon: "snowflake", category: .nature, fileName: "ice_cracking", isPremium: true),
        SoundItem(id: "volcanic_rumble", name: "Volcanic Rumble", icon: "mountain.2.fill", category: .nature, fileName: "volcanic_rumble", isPremium: true),
        SoundItem(id: "cave_dripping", name: "Cave Dripping", icon: "drop.fill", category: .nature, fileName: "cave_dripping", isPremium: false),
        SoundItem(id: "swamp_night", name: "Swamp Night", icon: "leaf.fill", category: .nature, fileName: "swamp_night", isPremium: true),
        SoundItem(id: "prairie_wind", name: "Prairie Wind", icon: "wind", category: .nature, fileName: "prairie_wind", isPremium: false),

        // MARK: Additional White Noise
        SoundItem(id: "green_noise", name: "Green Noise", icon: "waveform", category: .whiteNoise, fileName: "green_noise", isPremium: true),
        SoundItem(id: "red_noise", name: "Red Noise", icon: "waveform", category: .whiteNoise, fileName: "red_noise", isPremium: false),
        SoundItem(id: "orange_noise", name: "Orange Noise", icon: "waveform", category: .whiteNoise, fileName: "orange_noise", isPremium: true),
        SoundItem(id: "black_noise", name: "Black Noise", icon: "waveform", category: .whiteNoise, fileName: "black_noise", isPremium: true),

        // MARK: Additional Ambient
        SoundItem(id: "greenhouse", name: "Greenhouse", icon: "leaf.fill", category: .ambient, fileName: "greenhouse", isPremium: false),
        SoundItem(id: "aquarium", name: "Aquarium", icon: "water.waves", category: .ambient, fileName: "aquarium", isPremium: true),
        SoundItem(id: "rooftop_terrace", name: "Rooftop Terrace", icon: "building.2.fill", category: .ambient, fileName: "rooftop_terrace", isPremium: true),
        SoundItem(id: "ski_lodge", name: "Ski Lodge", icon: "snowflake", category: .ambient, fileName: "ski_lodge", isPremium: false),

        // MARK: Additional Instrumental
        SoundItem(id: "didgeridoo", name: "Didgeridoo", icon: "waveform.path", category: .instrumental, fileName: "didgeridoo", isPremium: true),
        SoundItem(id: "sitar", name: "Sitar", icon: "guitars.fill", category: .instrumental, fileName: "sitar", isPremium: true),
        SoundItem(id: "pan_flute", name: "Pan Flute", icon: "waveform.path", category: .instrumental, fileName: "pan_flute", isPremium: false),
        SoundItem(id: "handpan", name: "Handpan", icon: "circle.circle.fill", category: .instrumental, fileName: "handpan", isPremium: true),

        // MARK: Additional Meditation
        SoundItem(id: "walking_meditation", name: "Walking Meditation", icon: "figure.walk", category: .meditation, fileName: "walking_meditation", isPremium: true),
        SoundItem(id: "compassion_meditation", name: "Compassion Meditation", icon: "heart.fill", category: .meditation, fileName: "compassion_meditation", isPremium: true),

        // MARK: Additional Stories
        SoundItem(id: "sahara_nights", name: "Sahara Nights", icon: "book.fill", category: .stories, fileName: "sahara_nights", isPremium: true),
        SoundItem(id: "train_across_europe", name: "Train Across Europe", icon: "book.fill", category: .stories, fileName: "train_across_europe", isPremium: true),

        // MARK: Additional ASMR
        SoundItem(id: "chalk_writing", name: "Chalk Writing", icon: "pencil", category: .asmr, fileName: "chalk_writing", isPremium: true),
        SoundItem(id: "candle_flame", name: "Candle Flame", icon: "flame.fill", category: .asmr, fileName: "candle_flame", isPremium: true),
        SoundItem(id: "ice_cubes", name: "Ice Cubes", icon: "snowflake", category: .asmr, fileName: "ice_cubes", isPremium: true),
    ]

    // MARK: - Category Filters

    static func free() -> [SoundItem] { all.filter { !$0.isPremium } }
    static func nature() -> [SoundItem] { all.filter { $0.category == .nature } }
    static func whiteNoise() -> [SoundItem] { all.filter { $0.category == .whiteNoise } }
    static func ambient() -> [SoundItem] { all.filter { $0.category == .ambient } }
    static func instrumental() -> [SoundItem] { all.filter { $0.category == .instrumental } }
    static func meditation() -> [SoundItem] { all.filter { $0.category == .meditation } }
    static func stories() -> [SoundItem] { all.filter { $0.category == .stories } }
    static func asmr() -> [SoundItem] { all.filter { $0.category == .asmr } }
}
