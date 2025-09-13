//
//  GameViewModel.swift
//  first_app
//
//  Created by YU33 on 2025/9/13.
//

import SwiftUI
import Combine

@MainActor
final class GameViewModel: ObservableObject {

    // 遊戲設定
    let totalGameDuration: TimeInterval = 120 // 2 分鐘
    let perCustomerDuration: TimeInterval = 20 // 每位顧客 20 秒
    let maxQueueCount: Int = 2                 // 顧客最多 2 人
    let spawnDelayRange: ClosedRange<TimeInterval> = 3...5 // 新顧客延遲 3~5 秒

    // === 新增屬性 ===
    @Published var isGameStarted: Bool = false          // 選完難度才進入遊戲
    @Published var targetScore: Int = 0                 // 目標分數
    @Published var isChallengeSuccess: Bool = false     // 成功
    @Published var isChallengeFailure: Bool = false     // 失敗
    @Published var showDeliveryFeedback: Bool = false   // 顯示勾/叉
    @Published var deliveryFeedbackIsSuccess: Bool = false
    @Published var lastAvatarIndex: Int = 0

    
    // 遊戲狀態
    @Published var score: Int = 0
    @Published var remainingGameTime: TimeInterval = 120

    // 顧客佇列（最多 2）
    @Published var customers: [Customer] = []

    // 三個筒架
    @Published var stands: [IceCreamBuild] = Array(repeating: IceCreamBuild(), count: 3)
    @Published var selectedStandIndex: Int? = 0

    // 計時器
    private var gameTimer: Timer?

    // 補客排程
    private var pendingSpawnTask: Task<Void, Never>?

    // 遊戲是否進行中
    @Published var isRunning: Bool = false
    @Published var isGameOver: Bool = false

    init() {
        // 初始顯示難度選擇畫面
        isGameStarted = false
    }
    
    // === 新增：開始遊戲 ===
    func startGame(targetScore: Int) {
        self.targetScore = targetScore
        isGameStarted = true
        resetGame()
    }

    func resetGame() {
        score = 0
        remainingGameTime = totalGameDuration
        stands = Array(repeating: IceCreamBuild(), count: 3)
        selectedStandIndex = 0
        customers.removeAll()
        pendingSpawnTask?.cancel()
        isGameOver = false
        isRunning = true
        isChallengeSuccess = false
        isChallengeFailure = false

        // 先出第一位顧客
        spawnCustomer()
        // 第二位延遲 3~5 秒後再補（如果仍有空位）
        scheduleNextCustomerIfNeeded()
        startMainTimer()
    }

    private func startMainTimer() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isRunning else { return }

            // 總時間
            if self.remainingGameTime > 0 {
                self.remainingGameTime -= 1
            } else {
                self.endGame(success: self.score >= self.targetScore)
                return
            }

            // 顧客個別倒數
            for idx in self.customers.indices {
                if self.customers[idx].remaining > 0 {
                    self.customers[idx].remaining -= 1
                }
            }

            // 移除超時顧客
            let before = self.customers.count
            self.customers.removeAll { $0.isExpired }
            let removed = before - self.customers.count
            if removed > 0 {
                // 有人離場，排程補位
                self.scheduleNextCustomerIfNeeded()
            }

            // 若少於 2 位且沒有排程，排程補位
            self.scheduleNextCustomerIfNeeded()
            
            // 檢查是否達標
            if self.score >= self.targetScore {
                self.endGame(success: true)
            }
        }
    }

    private func endGame(success: Bool) {
        guard !isGameOver else { return }
        isRunning = false
        isGameOver = true
        gameTimer?.invalidate()
        pendingSpawnTask?.cancel()
        isChallengeSuccess = success
        isChallengeFailure = !success
    }

    private func makeRandomOrder() -> Order {
        let base = IceCreamBaseType.allCases.randomElement()!
        let scoops = (0..<base.allowedScoops).map { _ in Flavor.allCases.randomElement()! }
        let toppingCount = Int.random(in: 0...Topping.allCases.count)
        let tops = Array(Topping.allCases.shuffled().prefix(toppingCount))
        return Order(base: base, scoops: scoops, toppings: Set(tops), duration: perCustomerDuration)
    }

    private func spawnCustomer() {
        guard customers.count < maxQueueCount else { return }
        let order = makeRandomOrder()
        customers.append(Customer(order: order))
    }

    private func scheduleNextCustomerIfNeeded() {
        guard isRunning else { return }
        guard customers.count < maxQueueCount else { return }
        if pendingSpawnTask != nil { return }

        let delay = Double.random(in: spawnDelayRange)
        pendingSpawnTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                if self.isRunning, self.customers.count < self.maxQueueCount {
                    self.spawnCustomer()
                }
            } catch { }
            await MainActor.run {
                self.pendingSpawnTask = nil
                if self.isRunning, self.customers.count < self.maxQueueCount {
                    self.scheduleNextCustomerIfNeeded()
                }
            }
        }
    }
    
    func backToMainMenu() {
        isGameStarted = false
        isRunning = false
        isGameOver = false
        score = 0
        remainingGameTime = totalGameDuration
        customers.removeAll()
        stands = Array(repeating: IceCreamBuild(), count: 3)
        isChallengeSuccess = false
        isChallengeFailure = false
    }

    // MARK: - 互動：筒架選擇與操作（容器不可改；球只可追加；配料可自由切換）
    func selectStand(_ index: Int) {
        guard stands.indices.contains(index) else { return }
        selectedStandIndex = index
    }

    func setBaseForSelected(_ base: IceCreamBaseType) {
        guard let i = selectedStandIndex else { return }
        stands[i].setBaseIfEmpty(base)
        objectWillChange.send()
    }

    func addScoopToSelected(_ flavor: Flavor) {
        guard let i = selectedStandIndex else { return }
        stands[i].addScoopIfPossible(flavor)
        objectWillChange.send()
    }

    func toggleToppingForSelected(_ topping: Topping) {
        guard let i = selectedStandIndex else { return }
        stands[i].toggle(topping: topping)
        objectWillChange.send()
    }

    func clearSelected() {
        guard let i = selectedStandIndex else { return }
        stands[i] = IceCreamBuild()
    }

    // MARK: - 交付：指定工作台嘗試交付給任一顧客
    // 成功：+1 分、清空工作台、移除顧客並排程補位
    // 失敗：-1 分、清空工作台、顧客不變
    func deliverToAnyCustomer(standIndex: Int) -> Bool {
        guard isRunning, !isGameOver else { return false }
        guard stands.indices.contains(standIndex) else { return false }
        let build = stands[standIndex]

        let success: Bool
        if let matchIndex = customers.firstIndex(where: { compare(build: build, to: $0.order) }) {
            score += 1
            stands[standIndex] = IceCreamBuild()
            customers.remove(at: matchIndex)
            scheduleNextCustomerIfNeeded()
            success = true
        } else {
            score -= max(0, score - 1)
            stands[standIndex] = IceCreamBuild()
            success = false
        }
        
        notifyDeliveryFeedback(success: success)
        return success
    }
    
    func notifyDeliveryFeedback(success: Bool) {
        deliveryFeedbackIsSuccess = success
        showDeliveryFeedback = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000) // 0.7 秒
            showDeliveryFeedback = false
        }
    }

    func deliver(standIndex: Int, to customerID: UUID) -> Bool {
        guard stands.indices.contains(standIndex) else { return false }
        guard let cIndex = customers.firstIndex(where: { $0.id == customerID }) else { return false }
        let build = stands[standIndex]
        let order = customers[cIndex].order

        let ok = compare(build: build, to: order)
        if ok {
            score += 1
            stands[standIndex] = IceCreamBuild()
            customers.remove(at: cIndex)
            scheduleNextCustomerIfNeeded()
        } else {
            score -= 1
            stands[standIndex] = IceCreamBuild()
        }
        return ok
    }

    func compare(build: IceCreamBuild, to order: Order) -> Bool {
        guard let base = build.base else { return false }
        guard base == order.base else { return false }
        guard build.scoops.count == order.scoops.count else { return false }
        let buildCounts = Dictionary(grouping: build.scoops, by: { $0 }).mapValues(\.count)
        let orderCounts = Dictionary(grouping: order.scoops, by: { $0 }).mapValues(\.count)
        guard buildCounts == orderCounts else { return false }
        guard build.toppings == order.toppings else { return false }
        return true
    }

    deinit {
        gameTimer?.invalidate()
        pendingSpawnTask?.cancel()
    }
}
