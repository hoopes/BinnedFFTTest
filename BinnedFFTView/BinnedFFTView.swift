// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKitUI/

import Accelerate
import AudioKit
import SwiftUI
import PureSwiftUI
import Algorithms

class FFTModel: ObservableObject {
  @Published var amplitudes: [Float?] = Array(repeating: nil, count: 50)
  var nodeTap: FFTTap!
  var node: Node?
  var numberOfBars: Int = 50
  var maxAmplitude: Float = 0.0
  var minAmplitude: Float = -70.0
  var referenceValueForFFT: Float = 12.0

  func updateNode(_ node: Node, fftValidBinCount: FFTValidBinCount? = nil) {
    if node !== self.node {
      self.node = node
      nodeTap = FFTTap(node, fftValidBinCount: fftValidBinCount, callbackQueue: .main) { fftData in
        self.updateAmplitudes(fftData)
      }
      nodeTap.isNormalized = false
      nodeTap.start()
    }
  }

  func updateAmplitudes(_ fftFloats: [Float]) {
    var fftData = fftFloats
    for index in 0 ..< fftData.count {
      if fftData[index].isNaN { fftData[index] = 0.0 }
    }

    var one = Float(1.0)
    var zero = Float(0.0)
    var decibelNormalizationFactor = Float(1.0 / (maxAmplitude - minAmplitude))
    var decibelNormalizationOffset = Float(-minAmplitude / (maxAmplitude - minAmplitude))

    var decibels = [Float](repeating: 0, count: fftData.count)
    vDSP_vdbcon(fftData, 1, &referenceValueForFFT, &decibels, 1, vDSP_Length(fftData.count), 0)

    vDSP_vsmsa(decibels,
               1,
               &decibelNormalizationFactor,
               &decibelNormalizationOffset,
               &decibels,
               1,
               vDSP_Length(decibels.count))

    vDSP_vclip(decibels, 1, &zero, &one, &decibels, 1, vDSP_Length(decibels.count))

    // swap the amplitude array
    DispatchQueue.main.async {

      let numAmps = decibels.count
      let numBars = self.numberOfBars

      let strideLen = Int((Float(numAmps) / Float(numBars)).rounded(.up))
      let chunkSize = max(strideLen, 1)

      let maxAmpValPerGroup =
      decibels
        .chunks(ofCount: chunkSize)
        .map { chunk in chunk.max() ?? 0 }

      self.amplitudes = maxAmpValPerGroup
    }
  }

  func mockAudioInput() {
    var mockFloats = [Float]()
    for _ in 0...65 {
      mockFloats.append(Float.random(in: 0...0.1))
    }
    updateAmplitudes(mockFloats)
    let waitTime: TimeInterval = 0.1
    DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
      self.mockAudioInput()
    }
  }
}

public struct BinnedFFTView: View {
  @StateObject var fft = FFTModel()
  var node: Node
  @Binding var barCount: Float
  var linearGradient = LinearGradient(
    gradient: Gradient(colors: [.red, .yellow, .green]),
    startPoint: .top,
    endPoint: .center
  )
  var paddingFraction: CGFloat = 0.2
  var includeCaps: Bool = true
  var fftValidBinCount: FFTValidBinCount?
  var maxAmplitude: Float = -10.0
  var minAmplitude: Float = -150.0
  let maxBarCount: Int = 128
  var backgroundColor: Color = .black

  func calcBarWidth(geom: GeometryProxy) -> CGFloat {
    let width = geom.size.width
    let bc = self.numBars()
    let barWidth = width / CGFloat(bc)
    //    print ("Found bar width: \(barWidth); view width = \(width), bar count = \(bc)")
    return barWidth
  }

  func numBars() -> Int{
    return min(Int(self.barCount), self.maxBarCount)
  }

  func updateNumBars() {
    fft.numberOfBars = self.numBars()
  }

  public var body: some View {
    let bc = self.numBars()
    return GeometryReader { geom in

      HStack(spacing: 0.0) {
        ForEach(0 ..< bc, id: \.self) {
          if $0 < fft.amplitudes.count {
            if let amplitude = fft.amplitudes[$0] {
              AmplitudeBar(amplitude: amplitude,
                           linearGradient: linearGradient,
                           paddingFraction: paddingFraction,
                           includeCaps: includeCaps
              )
              .width(calcBarWidth(geom: geom))
            }
          } else {
            AmplitudeBar(amplitude: 0.0,
                         linearGradient: linearGradient,
                         paddingFraction: paddingFraction,
                         includeCaps: includeCaps,
                         backgroundColor: backgroundColor
            )
            .width(calcBarWidth(geom: geom))
          }
        }
      }.onAppear {
        fft.updateNode(node, fftValidBinCount: self.fftValidBinCount)
        fft.maxAmplitude = self.maxAmplitude
        fft.minAmplitude = self.minAmplitude
        self.updateNumBars()
      }
      .onChange(of: self.barCount) {
        self.updateNumBars()
      }
      .drawingGroup() // Metal powered rendering
      .background(backgroundColor)
    }
  }
}

struct AmplitudeBar: View {
  var amplitude: Float
  var linearGradient: LinearGradient
  var paddingFraction: CGFloat = 0.2
  var includeCaps: Bool = true
  var backgroundColor: Color = .black

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        // Colored rectangle in back of ZStack
        Rectangle()
          .fill(linearGradient)

        // Dynamic black mask padded from bottom in relation to the amplitude
        Rectangle()
          .fill(backgroundColor)
          .mask(Rectangle().padding(.bottom, geometry.size.height * CGFloat(amplitude)))
          .animation(.easeOut(duration: 0.15), value: amplitude)

        // White bar with slower animation for floating effect
        if includeCaps {
          addCap(width: geometry.size.width, height: geometry.size.height)
        }
      }
      //      .frame(width: self.width)
      .padding(geometry.size.width * paddingFraction / 2)
      .border(backgroundColor, width: geometry.size.width * paddingFraction / 2)
    }
  }

  // Creates the Cap View - separate method allows variable definitions inside a GeometryReader
  func addCap(width: CGFloat, height: CGFloat) -> some View {
    let padding = width * paddingFraction / 2
    let capHeight = height * 0.005
    let capDisplacement = height * 0.02
    let capOffset = -height * CGFloat(amplitude) - capDisplacement - padding * 2
    let capMaxOffset = -height + capHeight + padding * 2

    return Rectangle()
      .fill(Color.white)
      .frame(height: capHeight)
      .offset(x: 0.0, y: -height > capOffset - capHeight ? capMaxOffset : capOffset) // prevents offset from pushing cap outside of its frame
      .animation(.easeOut(duration: 0.6), value: amplitude)
  }
}
