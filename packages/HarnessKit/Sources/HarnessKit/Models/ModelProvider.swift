public enum ModelProvider: Sendable {
    case onDevice(OnDeviceModel)
    case cloud(CloudModel)
}

public enum OnDeviceModel: Sendable {
    case foundation
}

public enum CloudModel: Sendable {
    case claude
    case gpt
}

extension ModelProvider {
    /// Human-readable label used in traces and console UI.
    public var label: String {
        switch self {
        case .onDevice(.foundation):
            return "Apple Foundation Models (on-device)"
        case .cloud(.claude):
            return "Anthropic Claude (cloud)"
        case .cloud(.gpt):
            return "OpenAI GPT (cloud)"
        }
    }

    public var isOnDevice: Bool {
        if case .onDevice = self { return true }
        return false
    }
}
