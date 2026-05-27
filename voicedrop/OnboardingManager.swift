import Foundation

@Observable
final class OnboardingManager {
    enum Step: Int, CaseIterable {
        case permissions, done
    }

    private(set) var currentStep: Step
    var onComplete: (() -> Void)?

    var isComplete: Bool { currentStep == .done }

    init() {
        let saved = UserDefaults.standard.integer(forKey: "onboardingStep")
        currentStep = Step(rawValue: saved) ?? .permissions
    }

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
        UserDefaults.standard.set(currentStep.rawValue, forKey: "onboardingStep")
        if currentStep == .done { onComplete?() }
    }
}
