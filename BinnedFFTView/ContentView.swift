//
//  ContentView.swift
//  BinnedFFTView
//
//  Created by Matthew Hoopes on 1/14/24.
//

import AudioKit
import AudioKitUI
import SwiftUI

struct ContentView: View {

  @State var freq: Float = 440.0
  @State var widthPx: Float = 100.0

  let engine: AudioEngine!
  let osc: PlaygroundOscillator!

  init() {
    engine = AudioEngine()
    osc = PlaygroundOscillator()
    engine.output = osc
    try! engine.start()
  }

  var body: some View {
    GeometryReader { geom in
      VStack {
        HStack {
          Spacer()
          Button(action: { osc.start() }) { Text ("Start") }
          Spacer()
          Button(action: { osc.stop() }) { Text ("Stop") }
          Spacer()
        }
        Text("Settings.sampleRate: \(Settings.sampleRate)")
        Text("Freq (Hz): \(freq)")
        Text("Width (px): \(widthPx)")
        Slider(value: $freq, in: 20...20000, step: 1).padding()
        Slider(value: $widthPx, in: 20...Float(geom.size.width - 50), step: 1).padding()

        HStack {
          BinnedFFTView(
            node: osc,
            barCount: $widthPx
          )
        }
        .frame(width: CGFloat(self.widthPx), height: 100)
      }
      .onChange(of: freq) {
        osc.frequency = freq
      }
    }
  }
}

#Preview {
  ContentView()
}
