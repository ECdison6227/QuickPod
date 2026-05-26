import SwiftUI

enum OnboardingScene: Int, CaseIterable {
    case intro = 0
    case statusBar = 1
    case antiSleep = 2
    case screenCleaner = 3
    case quickSwitcher = 4
    
    var title: String {
        switch self {
        case .intro: return "欢迎使用 QuickPod"
        case .statusBar: return "状态栏快捷面板"
        case .antiSleep: return "防睡眠功能"
        case .screenCleaner: return "屏幕清洁"
        case .quickSwitcher: return "快速切换器"
        }
    }
    
    var description: String {
        switch self {
        case .intro: return "一款强大的 macOS 效率工具，让您的工作更高效"
        case .statusBar: return "点击状态栏图标打开快捷面板，快速访问常用功能"
        case .antiSleep: return "防止 Mac 自动休眠，保持工作不间断"
        case .screenCleaner: return "全屏清洁模式，让屏幕更清晰"
        case .quickSwitcher: return "按住快捷键呼出圆形菜单，快速切换功能"
        }
    }
    
    var icon: String {
        switch self {
        case .intro: return "bolt.circle.fill"
        case .statusBar: return "menubar.rectangle"
        case .antiSleep: return "moon.zzz.fill"
        case .screenCleaner: return "sparkles"
        case .quickSwitcher: return "switch"
        }
    }
    
    var duration: Double {
        switch self {
        case .intro: return 3.0
        case .statusBar: return 4.0
        case .antiSleep: return 3.0
        case .screenCleaner: return 3.0
        case .quickSwitcher: return 3.0
        }
    }
}

struct OnboardingAnimationView: View {
    @Binding var isPresented: Bool
    @State private var currentScene = 0
    @State private var isAnimating = true
    @State private var showSkipButton = false
    
    private let scenes = OnboardingScene.allCases
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.12, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack(spacing: 6) {
                    ForEach(scenes.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(currentScene >= index ? Color.blue : Color.white.opacity(0.2))
                            .frame(height: 2)
                            .scaleEffect(x: currentScene == index ? 1.2 : 1.0, anchor: .leading)
                            .animation(.easeInOut(duration: 0.3), value: currentScene)
                    }
                }
                .padding(.top, 40)
                .padding(.horizontal, 30)
                
                Spacer()
                
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .animation(.easeInOut(duration: 1.5).repeatForever(), value: isAnimating)
                        
                        Image(systemName: scenes[currentScene].icon)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(Angle(degrees: isAnimating ? 0 : -5))
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                    }
                    
                    Text(scenes[currentScene].title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 10)
                        .animation(.easeOut(duration: 0.5), value: isAnimating)
                    
                    Text(scenes[currentScene].description)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 10)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: isAnimating)
                }
                
                Spacer()
                
                HStack {
                    Button("跳过") {
                        completeOnboarding()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .opacity(showSkipButton ? 1.0 : 0.0)
                    
                    Spacer()
                    
                    if currentScene < scenes.count - 1 {
                        Button("下一步") {
                            nextScene()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    } else {
                        Button("开始使用") {
                            completeOnboarding()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding(.bottom, 40)
                .padding(.horizontal, 30)
            }
        }
        .onAppear {
            startAutoAdvance()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showSkipButton = true
            }
        }
    }
    
    private func startAutoAdvance() {
        guard currentScene < scenes.count else { return }
        
        let duration = scenes[currentScene].duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if currentScene < scenes.count - 1 {
                nextScene()
            }
        }
    }
    
    private func nextScene() {
        isAnimating = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentScene += 1
            if currentScene < scenes.count {
                isAnimating = true
                startAutoAdvance()
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "QuickPod.hasCompletedOnboarding")
        isPresented = false
    }
}

struct OnboardingAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingAnimationView(isPresented: .constant(true))
            .frame(width: 440, height: 640)
    }
}