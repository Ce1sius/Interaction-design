import Foundation

protocol MateProfileStore {
    func load() -> MateProfile
    func save(_ profile: MateProfile)
    func reset()
}

struct UserDefaultsMateProfileStore: MateProfileStore {
    private let key: String
    private let defaults: UserDefaults

    init(key: String = "PathMate.MateProfile.v1", defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    func load() -> MateProfile {
        guard let data = defaults.data(forKey: key) else {
            return .initial
        }
        return (try? JSONDecoder().decode(MateProfile.self, from: data)) ?? .initial
    }

    func save(_ profile: MateProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    func reset() {
        defaults.removeObject(forKey: key)
    }
}
