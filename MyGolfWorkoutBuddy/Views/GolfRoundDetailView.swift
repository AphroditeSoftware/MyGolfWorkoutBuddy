//
//  GolfRoundDetailView.swift
//  MyGolfWorkoutBuddy
//
//  Created by Janene Pappas on 7/6/26.
//
//  Detail screen for one round: summary stats, heart-rate and walking-speed
//  charts (with cart time shaded), and the list of detected swings.
//

import SwiftUI
import Charts
import UIKit

struct GolfRoundDetailView: View {
    let round: GolfRound
    let store: GolfRoundsStore

    @State private var averageHeartRate: Double?
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var isLoadingHeartRate = true

    @State private var speedSamples: [SpeedSample] = []
    @State private var isLoadingSpeed = true

    @State private var zoomedChart: ZoomableChart?

    var body: some View {
        List {
            Section {
                statRow(systemImage: "calendar", title: "Date", value: round.formattedDate)
                statRow(systemImage: "clock", title: "Duration", value: round.formattedDuration)
                if let calories = round.formattedCalories {
                    statRow(systemImage: "flame", title: "Calories Burned", value: calories, imageColor: .calorieFlame)
                }
                if let distance = round.formattedDistance {
                    statRow(systemImage: "figure.walk", title: "Distance", value: distance)
                }
            }
            
            Section("Heart Rate") {
                if isLoadingHeartRate {
                    HStack {
                        ProgressView()
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                    }
                } else if averageHeartRate == nil && heartRateSamples.isEmpty {
                    Text("No heart rate data for this round.")
                        .foregroundStyle(.secondary)
                } else {
                    if let averageHeartRate {
                        statRow(systemImage: "heart.fill", title: "Average", value: String(format: NSLocalizedString("%.0f BPM", comment: "Average heart rate in beats per minute"), averageHeartRate), imageColor: .red)
                    }
                    if !heartRateSamples.isEmpty {
                        heartRateChart
                    }
                }
            }

            Section("Speed") {
                if isLoadingSpeed {
                    HStack {
                        ProgressView()
                        Text("Loading…")
                            .foregroundStyle(.secondary)
                    }
                } else if speedSamples.isEmpty {
                    Text("No speed data for this round.")
                        .foregroundStyle(.secondary)
                } else {
                    speedChart
                }
            }

            Section("Golf Swings") {
                statRow(systemImage: "figure.golf", title: "Swings Detected", value: "\(round.swingCount)")

                if !round.swingTimestamps.isEmpty {
                    ForEach(Array(round.swingTimestamps.enumerated()), id: \.offset) { index, timestamp in
                        HStack {
                            Text("Swing \(index + 1)")
                            Spacer()
                            Text(relativeOffset(for: timestamp))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }


        }
        .navigationTitle("Round Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            async let average = store.averageHeartRate(for: round)
            async let samples = store.heartRateSamples(for: round)
            async let speed = store.speedSamples(for: round)
            averageHeartRate = await average
            heartRateSamples = await samples
            isLoadingHeartRate = false
            speedSamples = await speed
            isLoadingSpeed = false
        }
        .fullScreenCover(item: $zoomedChart) { chart in
            switch chart {
            case .heartRate:
                ChartZoomView(title: "Heart Rate") { heartRateChartContent }
            case .speed:
                ChartZoomView(title: "Speed") { speedChartContent }
            }
        }
    }

    /// The heart rate chart itself, without any fixed size, so it can be shown
    /// inline or filled into the full-screen zoom view.
    private var heartRateChartContent: some View {
        Chart(heartRateSamples) { sample in
            LineMark(
                x: .value("Time", sample.date),
                y: .value("BPM", sample.bpm)
            )
            .foregroundStyle(Color.calorieFlame)
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }

    private var heartRateChart: some View {
        heartRateChartContent
            .frame(height: 160)
            .overlay(alignment: .topTrailing) { expandHint }
            .contentShape(Rectangle())
            .onTapGesture { openChart(.heartRate) }
            .padding(.vertical, 4)
    }

    /// A speed sample tagged with which contiguous run (between cart pauses) it
    /// belongs to, so the chart can draw each run as its own unconnected line.
    private struct SegmentedSpeedSample: Identifiable {
        let sample: SpeedSample
        let segment: Int
        var id: UUID { sample.id }
    }

    /// Speed samples split into segments by the round's cart intervals: any point
    /// inside a cart pause is dropped, and each point's segment is the number of
    /// cart intervals that have already ended before it.
    private var segmentedSpeedSamples: [SegmentedSpeedSample] {
        let intervals = round.cartIntervals.sorted { $0.start < $1.start }
        return speedSamples.compactMap { sample in
            if intervals.contains(where: { $0.contains(sample.date) }) {
                return nil
            }
            let segment = intervals.filter { $0.end <= sample.date }.count
            return SegmentedSpeedSample(sample: sample, segment: segment)
        }
    }

    /// The speed chart itself, without any fixed size, so it can be shown inline
    /// or filled into the full-screen zoom view.
    private var speedChartContent: some View {
        Chart {
            // Shade the stretches the round was paused for a cart ride so the
            // line bridging that gap isn't mistaken for actual movement.
            ForEach(round.cartIntervals, id: \.self) { interval in
                RectangleMark(
                    xStart: .value("Cart start", interval.start),
                    xEnd: .value("Cart end", interval.end)
                )
                .foregroundStyle(.gray.opacity(0.18))
            }

            // Split the line into a separate series on each side of a cart
            // gap so it isn't drawn straight across the paused stretch.
            ForEach(segmentedSpeedSamples) { item in
                LineMark(
                    x: .value("Time", item.sample.date),
                    y: .value("mph", item.sample.milesPerHour),
                    series: .value("Segment", item.segment)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
    }

    private var speedChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            speedChartContent
                .frame(height: 160)
                .overlay(alignment: .topTrailing) { expandHint }
                .contentShape(Rectangle())
                .onTapGesture { openChart(.speed) }

            if !round.cartIntervals.isEmpty {
                Label("Shaded time was spent in a cart (paused).", systemImage: "car.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// Small affordance hinting the chart can be tapped to open full screen.
    private var expandHint: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(6)
    }

    private func statRow(systemImage: String, title: String, value: String, imageColor: Color? = nil) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(imageColor ?? Color.accentColor)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    /// Presents the full-screen chart without the slide-up animation, so the
    /// detail view isn't visible behind it. The rotation to landscape happens in
    /// `ChartZoomView.onAppear`, once the opaque cover is actually on screen.
    private func openChart(_ chart: ZoomableChart) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { zoomedChart = chart }
    }

    private func relativeOffset(for timestamp: Date) -> String {
        let seconds = Int(timestamp.timeIntervalSince(round.startDate))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: NSLocalizedString("%d:%02d into round", comment: "Time offset of a swing into the round"), minutes, remainingSeconds)
    }
}

/// Identifies which chart is currently shown full screen.
private enum ZoomableChart: Identifiable {
    case heartRate
    case speed
    var id: Self { self }
}

/// Forces the app (and device) into `mask`, overriding the user's Rotation Lock,
/// so the full-screen chart can be shown in landscape and portrait restored after.
private func forceOrientation(_ mask: UIInterfaceOrientationMask) {
    AppDelegate.orientationLock = mask
    guard let scene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
    scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
    var controller = scene.keyWindow?.rootViewController
    while let presented = controller?.presentedViewController {
        controller = presented
    }
    controller?.setNeedsUpdateOfSupportedInterfaceOrientations()
}

/// Presents a single chart full screen with pinch-to-zoom and drag-to-pan, plus
/// a back chevron in the upper-left to return.
private struct ChartZoomView<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    // Fades the chart in over the rotation so the opaque background covers the
    // detail view immediately while the contents ease in (rather than snapping).
    @State private var contentVisible = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
                .ignoresSafeArea()

            content
                .padding(24)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(transformGesture)
                .onTapGesture(count: 2) {
                    withAnimation(.spring) { resetTransform() }
                }
                .opacity(contentVisible ? 1 : 0)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    // Rotate back to portrait first, then dismiss, so the detail
                    // view isn't briefly revealed in landscape.
                    forceOrientation(.portrait)
                    Task {
                        try? await Task.sleep(for: .seconds(0.35))
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.title2.weight(.semibold))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Back")

                Text(title)
                    .font(.headline)

                Text("Pinch to zoom · double-tap to reset")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .opacity(contentVisible ? 1 : 0)
        }
        .onAppear {
            // Rotate only after the opaque cover is on screen, so the rotation
            // doesn't snapshot (and flash) the detail view behind it.
            DispatchQueue.main.async { forceOrientation(.landscape) }
            withAnimation(.easeOut(duration: 0.45)) { contentVisible = true }
        }
        // Safety net in case the cover is dismissed without the back button.
        .onDisappear { forceOrientation(.portrait) }
    }

    private var transformGesture: some Gesture {
        let magnify = MagnifyGesture()
            .onChanged { scale = max(0.5, lastScale * $0.magnification) }
            .onEnded { _ in lastScale = scale }
        let drag = DragGesture()
            .onChanged {
                offset = CGSize(
                    width: lastOffset.width + $0.translation.width,
                    height: lastOffset.height + $0.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
        return magnify.simultaneously(with: drag)
    }

    private func resetTransform() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}

#if DEBUG
#Preview {
    let start = Date.now
    let round = GolfRound(
        id: UUID(),
        startDate: start,
        endDate: start.addingTimeInterval(3600),
        duration: 3600,
        totalEnergyBurned: 450,
        totalDistance: 4800,
        swingCount: 3,
        swingTimestamps: [
            start.addingTimeInterval(120),
            start.addingTimeInterval(400),
            start.addingTimeInterval(900)
        ],
        cartIntervals: [
            DateInterval(start: start.addingTimeInterval(1320), end: start.addingTimeInterval(1560)),
            DateInterval(start: start.addingTimeInterval(2760), end: start.addingTimeInterval(2940))
        ]
    )

    // Synthetic heart rate curve so the chart has something to draw.
    let bpms: [Double] = [92, 104, 118, 131, 126, 140, 135, 122, 110, 98]
    let samples = bpms.enumerated().map { index, bpm in
        HeartRateSample(date: start.addingTimeInterval(Double(index) * 360), bpm: bpm)
    }

    // Synthetic walking-speed curve (mph) so the speed chart has something to draw.
    let speeds: [Double] = [0.0, 2.6, 3.1, 2.9, 0.2, 2.8, 3.0, 2.7, 0.1, 2.5]
    let speedSamples = speeds.enumerated().map { index, mph in
        SpeedSample(date: start.addingTimeInterval(Double(index) * 360), milesPerHour: mph)
    }

    return NavigationStack {
        GolfRoundDetailView(
            round: round,
            store: .preview(
                rounds: [round],
                heartRateSamples: [round.id: samples],
                speedSamples: [round.id: speedSamples]
            )
        )
    }
}
#endif
