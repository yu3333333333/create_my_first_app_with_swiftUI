//
//  Models.swift
//  first_app
//
//  Created by YU33 on 2025/9/13.
//

import SwiftUI

enum IceCreamBaseType: String, CaseIterable, Codable, Hashable {
    case singleCone = "單筒"
    case doubleCone = "雙筒"
    case bowl = "大碗"

    var allowedScoops: Int {
        switch self {
        case .singleCone: return 1
        case .doubleCone: return 2
        case .bowl: return 3
        }
    }

    var color: Color {
        switch self {
        case .singleCone: return .orange
        case .doubleCone: return .brown
        case .bowl: return .blue
        }
    }
}

enum Flavor: String, CaseIterable, Codable, Hashable {
    case strawberry = "草莓"
    case guava = "芭樂"
    case chocolate = "巧克力"

    var color: Color {
        switch self {
        case .strawberry: return .pink
        case .guava: return .green
        case .chocolate: return .brown
        }
    }
}

enum Topping: String, CaseIterable, Codable, Hashable {
    case sprinkles = "彩色巧克力米"
    case stick = "巧克力棒"
    case cherry = "櫻桃"

    var symbolName: String {
        switch self {
        case .sprinkles: return "sparkles"
        case .stick: return "line.diagonal"
        case .cherry: return "circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .sprinkles: return .purple
        case .stick: return .brown
        case .cherry: return .red
        }
    }
}

struct IceCreamBuild: Identifiable, Codable, Hashable {
    let id: UUID
    var base: IceCreamBaseType?
    var scoops: [Flavor]
    var toppings: Set<Topping>

    init(id: UUID = UUID(), base: IceCreamBaseType? = nil, scoops: [Flavor] = [], toppings: Set<Topping> = []) {
        self.id = id
        self.base = base
        self.scoops = scoops
        self.toppings = toppings
    }

    // 設定容器：僅當尚未選過容器時可設定；一旦設定 base 就不再允許變更
    mutating func setBaseIfEmpty(_ newBase: IceCreamBaseType) {
        guard base == nil else { return }
        base = newBase
        if scoops.count > newBase.allowedScoops {
            scoops = Array(scoops.prefix(newBase.allowedScoops))
        }
    }

    // 加球：需已有容器，且未達上限即可追加；不可移除
    mutating func addScoopIfPossible(_ flavor: Flavor) {
        guard let base else { return }
        guard scoops.count < base.allowedScoops else { return }
        scoops.append(flavor)
    }

    // 配料：可自由切換
    mutating func toggle(topping: Topping) {
        if toppings.contains(topping) {
            toppings.remove(topping)
        } else {
            toppings.insert(topping)
        }
    }

    var isComplete: Bool {
        guard let base else { return false }
        return scoops.count == base.allowedScoops
    }
}

struct Order: Identifiable, Hashable {
    let id = UUID()
    let base: IceCreamBaseType
    let scoops: [Flavor]
    let toppings: Set<Topping>
    let duration: TimeInterval
}

struct Customer: Identifiable, Hashable {
    let id: UUID
    let order: Order
    var remaining: TimeInterval
    let avatarName: String

    init(id: UUID = UUID(), order: Order) {
        self.id = id
        self.order = order
        self.remaining = order.duration
        self.avatarName = String(Int.random(in: 1...13))
    }

    var isExpired: Bool { remaining <= 0 }
}
