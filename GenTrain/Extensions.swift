//
//  Extensions.swift
//  GenTrain
//
//  Created by DrNeurosurg on 30.01.18.
//  Copyright © 2018 DrNeurosurg. All rights reserved.

import Foundation
import CoreImage
import AppKit
import CoreGraphics
import ImageIO


extension NSOpenPanel {
    var selectUrl: URL? {
        resolvesAliases = true
        title = "Select Diriectory"
        allowsMultipleSelection = false
        canChooseDirectories = true
        canChooseFiles = false
        canCreateDirectories = false
        allowedFileTypes = ["none"]
        allowsOtherFileTypes = false
        return runModal().rawValue == NSApplication.ModalResponse.OK.rawValue ? urls.first : nil
    }
}

extension CIImage
{
    func scale(width: CGFloat, height: CGFloat) ->CIImage
    {
        let sx = width / CGFloat( self.extent.width)
        let sy = height / CGFloat(self.extent.height)
        
        let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
        return self.transformed(by: scaleTransform)

    }
    
    func saveAs28GrayPNG(url: String, fileName:String) -> Bool
    {

        var destinationURL = URL(fileURLWithPath: url, isDirectory: true)
        destinationURL = destinationURL.appendingPathComponent(fileName)

        
        let imageRect:CGRect = CGRect(x:0, y:0, width:28, height: 28)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        let context = CGContext(data: nil, width: Int(imageRect.size.width), height: Int(imageRect.size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        let ci:CIContext = CIContext(cgContext: context!, options: [:])
        
        let pcg:CGImage = ci.createCGImage(self, from: self.extent)!
        
        context?.setFillColor(CGColor.white)
        context?.fill(imageRect)
        context?.draw(pcg, in: imageRect)
        let imageRef:CGImage = context!.makeImage()!
        
        let rep1 :NSBitmapImageRep = NSBitmapImageRep(cgImage: imageRef)

        
        let data:NSData = rep1.representation(using: .png, properties: [ : ]) as! NSData
        
        do {
            try data.write(to: destinationURL, options: .atomic)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
        
        return false
    }
    
}

extension NSImage {
    
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
    
    
    func scale(width:CGFloat, height:CGFloat) ->NSImage
    {
        var outImage = NSImage(size: NSSize(width:width, height:height))
        outImage.lockFocus()
        self.draw(in: NSRect(x:0, y:0, width:width, height:height))
        outImage.unlockFocus()
        return outImage
        
    }
    
    func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            try pngData?.write(to: url, options: options)
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
}

