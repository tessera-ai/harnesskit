/// Describes which model backend an agent uses. On-device models run locally
/// through Apple Foundation Models; cloud models route to a hosted API.
public enum ModelProvider: Sendable {
    /// Run on the device using Apple's on-device Foundation Models.
    case onDevice(OnDeviceModel)
    /// Run on a remote cloud service (e.g. Anthropic Claude, OpenAI GPT).
    case cloud(CloudModel)
}

/// On-device model variants supported by Tessera.
public enum OnDeviceModel: Sendable {
    /// Apple's built-in Foundation Models (available on iOS 26+ with Apple Intelligence).
    case foundation
}

/// Cloud-hosted model variants supported by Tessera.
public enum CloudModel: Sendable {
    /// Anthropic Claude.
    case claude
    /// OpenAI GPT.
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

    /// Whether this provider runs on-device (no network egress).
    public var isOnDevice: Bool {
        if case .onDevice = self { return true }
        return false
    }
}
