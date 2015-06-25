//
//  BufferProvider.swift
//  Model_IO_OSX
//
//  Created by Andriy K. on 6/20/15.
//  Copyright © 2015 Andriy K. All rights reserved.
//

import Cocoa
import simd
import Accelerate

/// This class is responsible for providing a uniformBuffer which will be passed to vertex shader. It holds n buffers. In case n == 3 for frame0 it will give buffer0 for frame1 - buffer1 for frame2 - buffer2 for frame3 - buffer0 and so on. It's user responsibility to make sure that GPU is not using that buffer before use. For details refer to wwdc session 604 (18:00).

class BufferProvider: NSObject {
  
  static let floatSize = sizeof(Float)
  static let floatsPerMatrix = 16
  static let numberOfMatrices = 2
  
  static var bufferSize: Int {
    return matrixSize * numberOfMatrices
  }
  
  static var matrixSize: Int {
    return floatSize * floatsPerMatrix
  }
  
  private(set) var indexOfAvaliableBuffer = 0
  private(set) var numberOfInflightBuffers: Int
  private var buffers:[MTLBuffer]
  
  private(set) var avaliableResourcesSemaphore:dispatch_semaphore_t
  
  init(inFlightBuffers: Int, device: MTLDevice) {
    
    avaliableResourcesSemaphore = dispatch_semaphore_create(inFlightBuffers)
    
    numberOfInflightBuffers = inFlightBuffers
    buffers = [MTLBuffer]()
    for (var i = 0; i < inFlightBuffers; i++) {
      let buffer = device.newBufferWithLength(BufferProvider.bufferSize, options: MTLResourceOptions.CPUCacheModeDefaultCache)
      buffer.label = "Uniform buffer"
      buffers.append(buffer)
    }
  }
  
  deinit{
    for _ in 0...numberOfInflightBuffers{
      dispatch_semaphore_signal(avaliableResourcesSemaphore)
    }
  }
  
  func bufferWithMatrices(var projectionMatrix: Matrix4, var modelViewMatrix: Matrix4) -> MTLBuffer {
    
    let uniformBuffer = self.buffers[indexOfAvaliableBuffer++]
    if indexOfAvaliableBuffer == numberOfInflightBuffers {
      indexOfAvaliableBuffer = 0
    }
    
    let col0 = float4(1, 0, 0, 0)
    let col1 = float4(0, 0.906307756, 0.42261827, 0)
    let col2 = float4(0, -0.42261827, 0.906307756, 0)
    let col3 = float4(0, 0, -4, 1)
    var modlV = float4x4([col0, col1, col2, col3])
    
    let size = BufferProvider.matrixSize
    memcpy(uniformBuffer.contents(), projectionMatrix.raw(), size)
    memcpy(uniformBuffer.contents() + size, modelViewMatrix.raw(), size)
    
    return uniformBuffer
  }
  
}
