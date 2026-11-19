import Foundation

struct MathProblem: Identifiable, Equatable, Sendable {
    let id: UUID
    let expression: String
    let answer: Int
    let difficulty: MathDifficulty

    init(
        id: UUID = UUID(),
        expression: String,
        answer: Int,
        difficulty: MathDifficulty
    ) {
        self.id = id
        self.expression = expression
        self.answer = answer
        self.difficulty = difficulty
    }
}

enum MathGenerator {
    static func generate(difficulty: MathDifficulty) -> MathProblem {
        switch difficulty {
        case .easy:
            return generateEasy()
        case .medium:
            return generateMedium()
        case .hard:
            return generateHard()
        case .extreme:
            return generateExtreme()
        }
    }

    static func generateBatch(difficulty: MathDifficulty, count: Int) -> [MathProblem] {
        let safeCount = max(1, count)
        return (0..<safeCount).map { _ in generate(difficulty: difficulty) }
    }

    private static func generateEasy() -> MathProblem {
        if Bool.random() {
            let a = Int.random(in: 14...89)
            let b = Int.random(in: 12...79)
            return MathProblem(
                expression: "\(a) + \(b)",
                answer: a + b,
                difficulty: .easy
            )
        } else {
            let b = Int.random(in: 12...58)
            let delta = Int.random(in: 11...49)
            let a = b + delta
            return MathProblem(
                expression: "\(a) - \(b)",
                answer: a - b,
                difficulty: .easy
            )
        }
    }

    private static func generateMedium() -> MathProblem {
        let a = Int.random(in: 7...17)
        let b = Int.random(in: 3...9)
        let product = a * b
        if Bool.random() && product > 30 {
            let c = Int.random(in: 11...min(45, product - 8))
            return MathProblem(
                expression: "(\(a) × \(b)) - \(c)",
                answer: product - c,
                difficulty: .medium
            )
        } else {
            let c = Int.random(in: 12...54)
            return MathProblem(
                expression: "(\(a) × \(b)) + \(c)",
                answer: product + c,
                difficulty: .medium
            )
        }
    }

    private static func generateHard() -> MathProblem {
        let a = Int.random(in: 12...29)
        let b = Int.random(in: 4...9)
        let c = Int.random(in: 24...88)
        let sum = (a * b) + c
        let d = Int.random(in: 14...min(65, sum - 12))
        return MathProblem(
            expression: "(\(a) × \(b)) + \(c) - \(d)",
            answer: sum - d,
            difficulty: .hard
        )
    }

    private static func generateExtreme() -> MathProblem {
        let a = Int.random(in: 19...39)
        let b = Int.random(in: 7...14)
        let c = Int.random(in: 6...15)
        let d = Int.random(in: 4...9)
        let diff = (a * b) - (c * d)
        let e = Int.random(in: 18...75)
        let finalValue = diff + e
        if finalValue <= 0 {
            let safeE = abs(diff) + Int.random(in: 20...60)
            return MathProblem(
                expression: "(\(a) × \(b)) - (\(c) × \(d)) + \(safeE)",
                answer: diff + safeE,
                difficulty: .extreme
            )
        }
        return MathProblem(
            expression: "(\(a) × \(b)) - (\(c) × \(d)) + \(e)",
            answer: finalValue,
            difficulty: .extreme
        )
    }
}
