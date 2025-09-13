//  ContentView.swift
//  first_app
//
//  Created by YU33 on 2025/9/13.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = GameViewModel()

    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

//            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 10) {
                // 最上方：分數 + 總倒數 + 目標分數
                topStatusBar

                // 顧客區：頭像 + 訂單泡泡
                customerArea

                // 2個工作台（每台有交付按鈕）
                standsArea

                // 操作區（無標題外框）
                controlsArea

                // 最底：置中重新開始
                restartButton
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // 交付成功/失敗短暫勾叉覆蓋
            if vm.showDeliveryFeedback {
                deliveryFeedbackOverlay(isSuccess: vm.deliveryFeedbackIsSuccess)
                    .transition(.opacity.combined(with: .scale))
            }

            // 遊戲結束覆蓋（顯示成功/失敗）
            if vm.isGameOver {
                gameOverOverlay
                    .transition(.opacity.combined(with: .scale))
            }

            // 開局前難度選擇
            if !vm.isGameStarted {
                difficultyOverlay
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut, value: vm.showDeliveryFeedback)
        .animation(.easeInOut, value: vm.isGameOver)
        .animation(.easeInOut, value: vm.isGameStarted)
    }

    // MARK: - 狀態列
    private var topStatusBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("分數：\(vm.score)")
                    .font(.title3).bold()
                Text("目標：\(vm.targetScore)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("剩餘：\(timeString(vm.remainingGameTime))")
                    .font(.title3).bold()
                ProgressView(value: vm.remainingGameTime, total: vm.totalGameDuration)
                    .tint(.blue)
                    .frame(width: 180)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - 顧客區（最多兩位，可能延遲出現）
    private var customerArea: some View {
        VStack(spacing: 8) {
            ForEach(vm.customers, id: \.id) { customer in
                HStack(alignment: .top, spacing: 16) {
                    // 顧客頭像
                    ZStack {
                        Image("\(customer.avatarName)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64)
                    }

                    // 訂單泡泡（顯示完整成品）
                    OrderPreview(order: customer.order)
                        .frame(width: 140, height: 100)
                        .padding(5)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // 顧客倒數條（只留進度條，縮短寬度）
                    VStack(alignment: .trailing) {
                        ProgressView(value: customer.remaining, total: customer.order.duration)
                            .tint(customer.remaining <= 5 ? .red : .green)
                            .frame(width: 100)
                    }
                }
            }

            // 如果少於 2 位，顯示占位（等待 3~5 秒補位）
            if vm.customers.count < 2 {
                HStack(alignment: .center, spacing: 16) {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .overlay(Image(systemName: "person.fill.questionmark").foregroundStyle(.secondary))
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.06))
                        .frame(height: 88)
                        .overlay(
                            Text("等待下一位顧客...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        )
                }
            }
        }
        .animation(.easeInOut, value: vm.customers)
    }

    // MARK: - 2個筒架（每台有交付按鈕）
    private var standsArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { i in
                    VStack(spacing: 6) {
                        StandView(build: vm.stands[i], isSelected: vm.selectedStandIndex == i)
                            .onTapGesture { vm.selectStand(i) }

                        // 交付按鈕：按下後嘗試與任一顧客匹配
                        Button {
                            let success = vm.deliverToAnyCustomer(standIndex: i)

                            vm.notifyDeliveryFeedback(success: success)

                            // 觸覺回饋
                            let generator = UINotificationFeedbackGenerator()
                            if success {
                                generator.notificationOccurred(.success)
                            } else {
                                generator.notificationOccurred(.error)
                            }
                        } label: {
                            Label("交付", systemImage: "hand.point.up.left.fill")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(vm.stands[i].isComplete ? Color.green.opacity(0.2) : Color.gray.opacity(0.15), in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 控制區（不鎖住按鈕外觀；由 VM 內部忽略不合法操作）
    private var controlsArea: some View {
        VStack(spacing: 8) {
            // 容器行
            HStack(spacing: 8) {
                ForEach(IceCreamBaseType.allCases, id: \.self) { base in
                    Button {
                        vm.setBaseForSelected(base)
                    } label: {
                        HStack(spacing: 6) {
                            containerIcon(for: base)
                            //Text(base.rawValue).font(.subheadline)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // 口味行
            HStack(spacing: 8) {
                ForEach(Flavor.allCases, id: \.self) { flavor in
                    Button {
                        vm.addScoopToSelected(flavor)
                    } label: {
                        HStack(spacing: 6) {
                            if flavor.rawValue == "草莓" {
                                Image("strawberry")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40)
                            }
                            else if flavor.rawValue == "芭樂" {
                                Image("guava")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40)
                            }
                            else {
                                Image("choco")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40)
                            }
                        }
                        .frame(maxWidth: 130, maxHeight: 50)
                        .background(flavor.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // 配料行
            HStack(spacing: 8) {
                ForEach(Topping.allCases, id: \.self) { topping in
                    Button {
                        vm.toggleToppingForSelected(topping)
                    } label: {
                        HStack(spacing: 0) {
                            if topping.rawValue == "櫻桃" {
                                Image("cherry")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 90)
                            }
                            else if topping.rawValue == "巧克力棒" {
                                Image("chocobar")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50)
                            }
                            else {
                                Image("candy")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30)
                            }
                        }
                        .frame(maxWidth: 130, maxHeight: 50)
                        .background(topping.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: - 最底部重新開始
    private var restartButton: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                vm.clearSelected()
            } label: {
                Label("丟棄", systemImage: "trash")
                    .padding(10)
                    .background(Color.white.opacity(1), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            // 回到主選單按鈕
            Button {
                withAnimation(.spring) {
                    vm.backToMainMenu()
                }
            } label: {
                Label("", systemImage: "house.fill")
                    .padding(10)
                    .background(Color.white.opacity(1), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            
            // 重新開始按鈕
            Button {
                withAnimation(.spring) {
                    vm.resetGame()
                }
            } label: {
                Label("", systemImage: "arrow.clockwise")
                    .padding(10)
                    .background(Color.white.opacity(1), in: RoundedRectangle(cornerRadius: 8))
            }
            Spacer()
            
        }
        .padding(.vertical, 6)
    }

    // MARK: - 遊戲結束覆蓋
    private var gameOverOverlay: some View {
        VStack(spacing: 16) {
            Text(vm.isChallengeSuccess ? "挑戰成功！🎊" : "挑戰失敗😩")
                .font(.largeTitle).bold()
            Text("你的分數：\(vm.score) / 目標：\(vm.targetScore)")
                .font(.title3)
            Button {
                withAnimation {
                    vm.resetGame()
                }
            } label: {
                Label("再玩一次", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }

    // MARK: - 難度選擇覆蓋
    private var difficultyOverlay: some View {
        VStack(spacing: 14) {
            Text("選擇難度")
                .font(.title).bold()
            Text("完成客人訂單加分！ 但小心 做錯給客人會扣分喔")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)

            HStack(spacing: 12) {
                DifficultyButton(title: "簡單", target: 5, color: .green) {
                    withAnimation { vm.startGame(targetScore: 5) }
                }
                DifficultyButton(title: "中等", target: 10, color: .yellow) {
                    withAnimation { vm.startGame(targetScore: 10) }
                }
                DifficultyButton(title: "困難", target: 15, color: .red) {
                    withAnimation { vm.startGame(targetScore: 15) }
                }
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }

    // MARK: - 交付勾叉短暫覆蓋
    private func deliveryFeedbackOverlay(isSuccess: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.001) // 接收點擊穿透
            ZStack {
                Circle()
                    .fill(isSuccess ? Color.green.opacity(0.85) : Color.red.opacity(0.85))
                    .frame(width: 120, height: 120)
                    .shadow(radius: 8)
                Image(systemName: isSuccess ? "checkmark" : "xmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }
            .transition(.scale.combined(with: .opacity))
        }
        .ignoresSafeArea()
    }

    // MARK: - 工具
    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    @ViewBuilder
    private func containerIcon(for base: IceCreamBaseType) -> some View {
        switch base {
        case .singleCone:
            Image("singlecone")
                .resizable()
                .scaledToFit()
                .frame(width: 50)
                .offset(y:10)
        case .doubleCone:
            Image("doublecone")
                .resizable()
                .scaledToFit()
                .frame(width: 60)
        case .bowl:
            Image("bowl")
                .resizable()
                .scaledToFit()
                .frame(width: 70)
                .offset(y:10)
        }
    }
}

// MARK: - 訂單成品預覽：球的 1/2/3 正確佈局（左右 + 上）
struct OrderPreview: View {
    let order: Order

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.06))

            containerView(for: order.base)
                .offset(y: -6)

            scoopsLayout(flavors: order.scoops)
                .offset(y: -42)

            HStack(spacing: -10) {
                ForEach(Array(order.toppings), id: \.self) { topping in
                    if topping.rawValue == "櫻桃" {
                        Image("cherry")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60)
                            .offset(y: 30)
                    }
                    else if topping.rawValue == "巧克力棒"
                    {
                        Image("chocobar")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y: 30)
                    }
                    else
                    {
                        Image("candy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30)
                            .offset(y: 30)
                    }
                }
            }
            .offset(y: -80)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func containerView(for base: IceCreamBaseType) -> some View {
        switch base {
        case .singleCone:
            Image("singlecone")
                .resizable()
                .scaledToFit()
                .frame(width: 60)
        case .doubleCone:
            Image("doublecone")
                .resizable()
                .scaledToFit()
                .frame(width: 60)
        case .bowl:
            Image("bowl")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .offset(y:20)
        }
    }

    @ViewBuilder
    private func scoopsLayout(flavors: [Flavor]) -> some View {
        switch flavors.count {
        case 1:
            if flavors[0] == .strawberry {
                Image("strawberry")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35)
                    .offset(y:-10)
                
            }
            else if flavors[0] == .guava {
                Image("guava")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35)
                    .offset(y:-10)
            }
            else {
                Image("choco")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35)
                    .offset(y:-10)
            }
        case 2:
            HStack(spacing: 2) {
                ForEach(0..<2, id: \.self) { i in
                    if flavors[i] == .strawberry {
                        Image("strawberry")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                            .offset(y:-15)
                    }
                    else if flavors[i] == .guava {
                        Image("guava")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                            .offset(y:-15)
                    }
                    else {
                        Image("choco")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                            .offset(y:-15)
                    }
                }
            }
        default:
            VStack(spacing: -2) {
                HStack(spacing: 1) {
                    ForEach(0..<2, id: \.self) { i in
                        if flavors[i] == .strawberry {
                            Image("strawberry")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35)
                                .offset(y:40)
                            
                        }
                        else if flavors[i] == .guava {
                            Image("guava")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35)
                                .offset(y:40)
                        }
                        else {
                            Image("choco")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 35)
                                .offset(y:40)
                        }
                    }
                }
                if flavors.count > 2 {
                    if flavors[2] == .strawberry {
                        Image("strawberry")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                            .offset(y: -10)
                    }
                    else if flavors[2] == .guava {
                        Image("guava")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                            .offset(y:-10)
                    }
                    else {
                        Image("choco")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                            .offset(y:-10)
                    }
                }
            }
        }
    }
}

// MARK: - 工作台視圖：球的 1/2/3 正確佈局（左右 + 上），選取以背景深淺表示
struct StandView: View {
    let build: IceCreamBuild
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                // 背景深淺表示選取狀態
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.secondary.opacity(0.18) : Color.secondary.opacity(0.08))
                    .frame(height: 140)

                if let base = build.base {
                    containerView(for: base)
                        .offset(y: -6)
                }

                scoopsLayout(flavors: build.scoops)
                    .offset(y: -42)

                HStack(spacing:-15) {
                    ForEach(Array(build.toppings), id: \.self) { topping in
                        if topping.rawValue == "櫻桃"
                        {
                            Image("cherry")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60)
                        }
                        else if topping.rawValue == "巧克力棒"
                        {
                            Image("chocobar")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70)
                        }
                        else
                        {
                            Image("candy")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30)
                        }
                    }
                }
                .offset(y: -80)
            }
            .frame(minWidth: 90, maxWidth: .infinity, minHeight: 140)
        }
    }

    @ViewBuilder
    private func containerView(for base: IceCreamBaseType) -> some View {
        switch base {
        case .singleCone:
            Image("singlecone")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
        case .doubleCone:
            Image("doublecone")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
        case .bowl:
            Image("bowl")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .offset(y:20)
        }
    }

    @ViewBuilder
    private func scoopsLayout(flavors: [Flavor]) -> some View {
        switch flavors.count {
        case 0:
            EmptyView()
        case 1:
            if flavors[0] == .strawberry {
                Image("strawberry")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                    .offset(y:-40)
            }
            else if flavors[0] == .guava {
                Image("guava")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                    .offset(y:-40)
            }
            else {
                Image("choco")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50)
                    .offset(y:-40)
            }
        case 2:
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { i in
                    if flavors[i] == .strawberry {
                        Image("strawberry")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y:-35)
                    }
                    else if flavors[i] == .guava {
                        Image("guava")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y:-35)
                    }
                    else {
                        Image("choco")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y:-35)
                    }
                }
            }
        default:
            VStack(spacing: -2) {
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { i in
                        if flavors[i] == .strawberry {
                            Image("strawberry")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                                .offset(y:30)
                        }
                        else if flavors[i] == .guava {
                            Image("guava")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                                .offset(y:30)
                        }
                        else {
                            Image("choco")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50)
                                .offset(y:30)
                        }
                    }
                }
                if flavors.count > 2 {
                    if flavors[2] == .strawberry {
                        Image("strawberry")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y: -40)
                    }
                    else if flavors[2] == .guava {
                        Image("guava")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y: -40)
                    }
                    else {
                        Image("choco")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50)
                            .offset(y: -40)
                    }
                }
            }
        }
    }
}

struct DifficultyButton: View {
    let title: String
    let target: Int
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text("\(target) 分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(minWidth: 90)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
