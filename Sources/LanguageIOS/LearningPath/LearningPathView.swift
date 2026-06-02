import SwiftUI

/// The post-onboarding home screen: a Duolingo-style winding path over a sea, themed
/// by the language the user chose. Tapping the active stop completes it, plays the
/// layer-reveal animation, and unlocks the next destination.
public struct LearningPathView: View {
    let language: TargetLanguage
    let store: AppStore
    private let journey: LearningJourney

    @Environment(\.appEnvironment) private var env
    @State private var activeLesson: ActiveLesson?
    @State private var showNoHearts = false
    @State private var showProfile = false
    @State private var showObjects = false
    @State private var showCollection = false
    @State private var showAI = false

    private enum ActiveLesson: Identifiable {
        case stop(LearningStop)
        case review(Lesson)
        var id: String {
            switch self {
            case .stop(let stop): "stop_\(stop.id)"
            case .review(let lesson): "review_\(lesson.stopId)"
            }
        }
    }

    public init(language: TargetLanguage, store: AppStore) {
        self.language = language
        self.store = store
        self.journey = LearningJourney.journey(for: language)
    }

    public var body: some View {
        let progress = store.progress(for: language)

        ZStack(alignment: .top) {
            SeaBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header(progress: progress)
                pathScroll(progress: progress)
            }
        }
        .overlay(alignment: .bottom) { practiceButton(progress: progress) }
        .onAppear {
            env.analytics.track(
                LearningPathAnalytics.mapViewed(
                    language: language,
                    completed: progress.completedCount,
                    total: journey.stopCount
                )
            )
        }
        #if os(iOS)
        .fullScreenCover(item: $activeLesson) { lessonHost(for: $0) }
        #else
        .sheet(item: $activeLesson) { lessonHost(for: $0) }
        #endif
        .alert("Canların bitti", isPresented: $showNoHearts) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(noHeartsMessage)
        }
        .sheet(isPresented: $showProfile) { profileSheet }
        .sheet(isPresented: $showObjects) { objectSheet }
        .sheet(isPresented: $showCollection) { collectionSheet }
        .sheet(isPresented: $showAI) {
            SentenceAnalysisView(speech: env.speech, language: language, onClose: { showAI = false })
        }
    }

    private var objectSheet: some View {
        ObjectCaptureView(
            store: store,
            speech: env.speech,
            language: language,
            onShowCollection: {
                showObjects = false
                showCollection = true
            },
            onClose: { showObjects = false }
        )
    }

    private var collectionSheet: some View {
        WordCollectionView(
            store: store,
            speech: env.speech,
            onCapture: {
                showCollection = false
                showObjects = true
            },
            onClose: { showCollection = false }
        )
    }

    private var profileSheet: some View {
        ProfileView(
            store: store,
            currentLanguage: language,
            onSwitchLanguage: { newLanguage in
                showProfile = false
                store.setTargetLanguage(newLanguage)
            },
            onRestartOnboarding: {
                showProfile = false
                store.resetAll()
            },
            onClose: { showProfile = false }
        )
    }

    private var noHeartsMessage: String {
        if let seconds = store.secondsUntilNextHeart() {
            let minutes = max(1, Int(seconds / 60))
            return String(localized: "Yeni can için ~\(minutes) dk bekle.")
        }
        return String(localized: "Birazdan canların yenilenecek.")
    }

    @ViewBuilder
    private func lessonHost(for active: ActiveLesson) -> some View {
        switch active {
        case .stop(let stop):
            LessonView(
                lesson: LessonBuilder.build(for: stop, language: language),
                analytics: env.analytics,
                speech: env.speech,
                onPassed: { stars in
                    store.recordLessonPassed(stopId: stop.id, stars: stars)
                    activeLesson = nil
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        store.completeCurrentStop(for: language, total: journey.stopCount)
                    }
                },
                onFailed: { store.recordLessonFailed() },
                onWordResult: { item, correct in store.recordWordResult(wordId: item.id, correct: correct) },
                onClose: { activeLesson = nil }
            )
        case .review(let lesson):
            LessonView(
                lesson: lesson,
                analytics: env.analytics,
                speech: env.speech,
                onPassed: { stars in
                    store.recordPracticeCompleted(stars: stars)
                    activeLesson = nil
                },
                onFailed: {},
                onWordResult: { item, correct in store.recordWordResult(wordId: item.id, correct: correct) },
                onClose: { activeLesson = nil }
            )
        }
    }

    @ViewBuilder
    private func practiceButton(progress: LearningProgress) -> some View {
        if progress.completedCount > 0 {
            Button {
                let completed = Array(journey.stops.prefix(progress.completedCount))
                if let lesson = LessonBuilder.review(
                    language: language,
                    completedStops: completed,
                    prioritized: store.missedWordIds
                ) {
                    activeLesson = .review(lesson)
                }
            } label: {
                Label("Pratik yap", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(MapTheme.teal))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 26)
        }
    }

    // MARK: Header

    private func header(progress: LearningProgress) -> some View {
        let total = journey.stopCount
        let done = min(progress.completedCount, total)

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(language.flag)
                    .font(.system(size: 34))

                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.isFinished(total: total) ? "\(journey.title) 🎉" : journey.title)
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundStyle(MapTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(journey.tagline)
                        .font(.caption)
                        .foregroundStyle(MapTheme.ink.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button { showAI = true } label: {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(MapTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(MapTheme.paper.opacity(0.9)))
                }
                .accessibilityLabel("AI cümle analizi")

                Button { showObjects = true } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                        .foregroundStyle(MapTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(MapTheme.paper.opacity(0.9)))
                }
                .accessibilityLabel("Objeleri öğren")

                Button { showProfile = true } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(MapTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(MapTheme.paper.opacity(0.9)))
                }
                .accessibilityLabel("Profil")

                Menu {
                    Button("İlerlemeyi sıfırla", role: .destructive) {
                        store.resetProgress(for: language)
                    }
                    Button("Onboarding'i tekrar gör", role: .destructive) {
                        store.resetAll()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MapTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(MapTheme.paper.opacity(0.9)))
                }
                .accessibilityLabel("Yolculuk seçenekleri")
            }

            progressBar(done: done, total: total)
            statsRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statPill(icon: "flame.fill", value: "\(store.streak)", tint: MapTheme.coral, label: "Seri: \(store.streak) gün")
            statPill(icon: "star.circle.fill", value: "\(store.xp) XP", tint: MapTheme.teal, label: "\(store.xp) XP")
            statPill(
                icon: store.dailyGoalReached ? "checkmark.circle.fill" : "target",
                value: "\(store.activitiesToday)/\(store.dailyGoalTarget)",
                tint: store.dailyGoalReached ? .green : MapTheme.teal,
                label: "Bugünkü hedef: \(store.activitiesToday) bölü \(store.dailyGoalTarget)"
            )
            Spacer()
            TimelineView(.periodic(from: Date(), by: 30)) { _ in
                heartsView
            }
        }
        .padding(.top, 2)
    }

    private var heartsView: some View {
        let hearts = store.availableHearts()
        return HStack(spacing: 5) {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(MapTheme.coral)
            Text("\(hearts)/\(store.maxHearts)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MapTheme.ink)
            if hearts < store.maxHearts, let seconds = store.secondsUntilNextHeart() {
                Text(formatRefill(seconds))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MapTheme.ink.opacity(0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hearts) can")
    }

    private func formatRefill(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        return minutes > 0 ? "\(minutes)dk" : "\(total)sn"
    }

    private func statPill(icon: String, value: String, tint: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(MapTheme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func progressBar(done: Int, total: Int) -> some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MapTheme.ink.opacity(0.12))
                    Capsule()
                        .fill(MapTheme.teal)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(done) / CGFloat(total) : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: done)
                }
            }
            .frame(height: 8)

            Text("\(done)/\(total)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(MapTheme.ink.opacity(0.7))
        }
    }

    // MARK: Path

    private func pathScroll(progress: LearningProgress) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                JourneyPathLayout(
                    journey: journey,
                    progress: progress,
                    starsForIndex: { store.stars(forStop: journey.stops[$0].id) }
                ) { index in
                    guard index < journey.stops.count else { return }
                    if store.canStartLesson() {
                        activeLesson = .stop(journey.stops[index])
                    } else {
                        showNoHearts = true
                    }
                }
            }
            .onAppear {
                let target = min(progress.completedCount, journey.stopCount - 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation { proxy.scrollTo(max(target, 0), anchor: .center) }
                }
            }
        }
    }
}

/// Lays out the stops along a vertical winding path and draws the connecting trail.
private struct JourneyPathLayout: View {
    let journey: LearningJourney
    let progress: LearningProgress
    let starsForIndex: (Int) -> Int
    let onTap: (Int) -> Void

    private let rowHeight: CGFloat = 172
    private let topPad: CGFloat = 36
    private let bottomPad: CGFloat = 96

    private var contentHeight: CGFloat {
        topPad + rowHeight * CGFloat(journey.stopCount) + bottomPad
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // Real VStack rows (not .offset) so each stop's layout position is correct
            // and `ScrollViewReader.scrollTo(index:)` can jump to the active stop.
            VStack(spacing: 0) {
                ForEach(Array(journey.stops.enumerated()), id: \.element.id) { index, stop in
                    StopNodeView(
                        stop: stop,
                        status: progress.status(forIndex: index),
                        stars: starsForIndex(index),
                        onTap: { onTap(index) }
                    )
                    .offset(x: xOffset(index: index, width: width))
                    .frame(maxWidth: .infinity)
                    .frame(height: rowHeight)
                    .id(index)
                }
            }
            .padding(.top, topPad)
            .padding(.bottom, bottomPad)
            .background(
                JourneyTrail(centers: centers(width: width), completedCount: progress.completedCount)
            )
        }
        .frame(height: contentHeight)
    }

    private func amplitude(width: CGFloat) -> CGFloat {
        min(width * 0.24, 96)
    }

    private func xOffset(index: Int, width: CGFloat) -> CGFloat {
        CGFloat(sin(Double(index) * 0.9)) * amplitude(width: width)
    }

    private func centers(width: CGFloat) -> [CGPoint] {
        (0..<journey.stopCount).map { index in
            CGPoint(
                x: width / 2 + xOffset(index: index, width: width),
                y: topPad + rowHeight * (CGFloat(index) + 0.5)
            )
        }
    }
}

/// The dotted winding trail; the segment up to the current stop is drawn brighter.
private struct JourneyTrail: View {
    let centers: [CGPoint]
    let completedCount: Int

    var body: some View {
        Canvas { context, _ in
            guard centers.count > 1 else { return }

            context.stroke(
                smoothPath(centers),
                with: .color(MapTheme.trailDim),
                style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [1, 18])
            )

            let doneIndex = min(max(completedCount, 0), centers.count - 1)
            if doneIndex >= 1 {
                context.stroke(
                    smoothPath(Array(centers[0...doneIndex])),
                    with: .color(MapTheme.trailDone),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
            }
        }
    }

    private func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 1..<points.count {
            let prev = points[index - 1]
            let current = points[index]
            let midY = (prev.y + current.y) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: prev.x, y: midY),
                control2: CGPoint(x: current.x, y: midY)
            )
        }
        return path
    }
}

/// Sea gradient with soft wave bands plus ambient life: drifting clouds, a sailboat,
/// and leaping dolphins. Purely decorative — sits behind the scrolling path, never
/// intercepts taps. Each element is procedural so it works before real art is added.
private struct SeaBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [MapTheme.seaTop, MapTheme.seaBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Soft foam bands for texture.
                ForEach(0..<3, id: \.self) { index in
                    Ellipse()
                        .fill(MapTheme.seaFoam.opacity(0.10))
                        .frame(width: w * 1.4, height: 120)
                        .position(x: w * (index % 2 == 0 ? 0.25 : 0.75), y: h * (0.2 + 0.3 * Double(index)))
                        .blur(radius: 8)
                }

                // Clouds drifting across the sky.
                DriftingCloud(size: 78, opacity: 0.85, amplitude: 26, duration: 19)
                    .position(x: w * 0.26, y: h * 0.16)
                DriftingCloud(size: 56, opacity: 0.7, amplitude: 22, duration: 24)
                    .position(x: w * 0.8, y: h * 0.11)
                DriftingCloud(size: 46, opacity: 0.6, amplitude: 18, duration: 15)
                    .position(x: w * 0.62, y: h * 0.23)

                // Dolphins leaping out of the water.
                LeapingDolphin(size: 64, duration: 3.0, delay: 0.0)
                    .position(x: w * 0.2, y: h * 0.6)
                LeapingDolphin(size: 46, duration: 3.7, delay: 1.4)
                    .position(x: w * 0.84, y: h * 0.82)

                // A sailboat bobbing on the waves.
                SailboatView()
                    .frame(width: 66, height: 62)
                    .position(x: w * 0.73, y: h * 0.47)
            }
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }
}

/// A cloud that sways gently back and forth.
private struct DriftingCloud: View {
    let size: CGFloat
    let opacity: Double
    let amplitude: CGFloat
    let duration: Double

    @State private var drift = false

    var body: some View {
        Image(systemName: "cloud.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size)
            .foregroundStyle(.white.opacity(opacity))
            .offset(x: drift ? amplitude : -amplitude)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
    }
}

/// A simple sailboat (hull + two sails + mast) that rocks and bobs.
private struct SailboatView: View {
    @State private var bob = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Main sail (right of mast).
                Path { path in
                    path.move(to: CGPoint(x: 0.5 * w, y: 0.04 * h))
                    path.addLine(to: CGPoint(x: 0.5 * w, y: 0.56 * h))
                    path.addLine(to: CGPoint(x: 0.92 * w, y: 0.56 * h))
                    path.closeSubpath()
                }
                .fill(MapTheme.paper)

                // Jib sail (left of mast).
                Path { path in
                    path.move(to: CGPoint(x: 0.46 * w, y: 0.13 * h))
                    path.addLine(to: CGPoint(x: 0.46 * w, y: 0.56 * h))
                    path.addLine(to: CGPoint(x: 0.12 * w, y: 0.56 * h))
                    path.closeSubpath()
                }
                .fill(MapTheme.paper.opacity(0.85))

                // Mast.
                Capsule()
                    .fill(MapTheme.ink.opacity(0.6))
                    .frame(width: max(2, 0.03 * w), height: 0.54 * h)
                    .position(x: 0.5 * w, y: 0.30 * h)

                // Hull.
                Path { path in
                    path.move(to: CGPoint(x: 0.05 * w, y: 0.60 * h))
                    path.addLine(to: CGPoint(x: 0.95 * w, y: 0.60 * h))
                    path.addQuadCurve(to: CGPoint(x: 0.5 * w, y: 0.99 * h), control: CGPoint(x: 0.85 * w, y: 0.96 * h))
                    path.addQuadCurve(to: CGPoint(x: 0.05 * w, y: 0.60 * h), control: CGPoint(x: 0.15 * w, y: 0.96 * h))
                    path.closeSubpath()
                }
                .fill(MapTheme.coral)
            }
        }
        .rotationEffect(.degrees(bob ? 3.5 : -3.5))
        .offset(y: bob ? 5 : -3)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                bob = true
            }
        }
    }
}

/// A dolphin that repeatedly arcs out of the water and dives back in.
///
/// Driven by `TimelineView(.animation)` rather than an animated state: the leap follows
/// a parabola (`sin`) that is zero at both ends, so a plain `withAnimation` between
/// endpoints would never lift it — the body must be recomputed every frame.
private struct LeapingDolphin: View {
    let size: CGFloat
    let duration: Double
    let delay: Double

    private var leapHeight: CGFloat { size * 0.95 }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate - delay
            let cycles = elapsed / duration
            let phase = cycles - floor(cycles)        // 0..1 within each leap
            let arc = sin(phase * .pi)                // 0 at water, 1 at apex

            DolphinShape()
                .fill(MapTheme.ink.opacity(0.62))
                .frame(width: size, height: size * 0.7)
                .rotationEffect(.degrees((phase * 2 - 1) * 24))
                .offset(y: -leapHeight * CGFloat(arc))
                .opacity(min(1.0, arc * 1.6))
        }
    }
}

/// A stylized leaping-dolphin silhouette (body + dorsal fin + forked tail), facing right.
struct DolphinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        var path = Path()
        // Body crescent: nose at right, arching up over the back to the tail base at left.
        path.move(to: pt(0.97, 0.50))
        path.addQuadCurve(to: pt(0.20, 0.34), control: pt(0.62, 0.13))
        path.addQuadCurve(to: pt(0.97, 0.50), control: pt(0.55, 0.94))
        path.closeSubpath()

        // Dorsal fin.
        path.move(to: pt(0.46, 0.26))
        path.addLine(to: pt(0.60, 0.26))
        path.addLine(to: pt(0.49, 0.07))
        path.closeSubpath()

        // Tail flukes.
        path.move(to: pt(0.22, 0.36))
        path.addLine(to: pt(0.02, 0.19))
        path.addLine(to: pt(0.11, 0.40))
        path.closeSubpath()

        path.move(to: pt(0.22, 0.36))
        path.addLine(to: pt(0.02, 0.55))
        path.addLine(to: pt(0.13, 0.40))
        path.closeSubpath()

        return path
    }
}

#Preview {
    LearningPathView(language: .englishUS, store: AppStore(defaults: UserDefaults(suiteName: "preview")!))
}
