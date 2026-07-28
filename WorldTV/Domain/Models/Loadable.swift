import Foundation

enum Loadable<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(AppError)
}

enum AppError: Error, Equatable, Sendable {
    case catalogUnavailable
}
