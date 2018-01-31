//
//  TextDetector.swift
//  GenTrain
//
//  Created by DrNeurosurg on 30.01.18.
//  Copyright © 2018 DrNeurosurg. All rights reserved.

import Cocoa
import Vision

class TextDetector: NSObject {

    var requests = [VNRequest]()
    var result:[VNTextObservation]?
    
    func detectText(ciImage: CIImage) -> [VNTextObservation]
    {
        var result:[VNTextObservation]?
        let requestOptions:[VNImageOption : Any] = [:]
        
        //CGImagePropertyOrientation(rawValue: 4)  4 -> LandscapeRight (HomeButton on the right)
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: CGImagePropertyOrientation(rawValue: 0)!, options: requestOptions)
        let request:VNDetectTextRectanglesRequest = VNDetectTextRectanglesRequest.init(completionHandler: { (request, error) in
            if( (error) != nil){
                print("Got Error In Run Text Dectect Request");
                
            }else{
                guard let observations = request.results else {print("no result"); return}
                
                result = observations.map({($0 as? VNTextObservation)!})
            }
            
        })
        
        request.reportCharacterBoxes = true
        request.preferBackgroundProcessing = false
        do {
            try handler.perform([request])
            return result!;
        } catch {
            return result!;
        }
    }
    
    func scaleRect(orgRect:CGRect, scaleTo:CGRect) -> CGRect
    {
        var scaledRect = CGRect()
        scaledRect.size.width = orgRect.size.width * scaleTo.size.width
        scaledRect.size.height = orgRect.size.height * scaleTo.size.height
        scaledRect.origin.y = scaleTo.size.height * orgRect.origin.y
        scaledRect.origin.x = orgRect.origin.x * scaleTo.size.width
        
        return scaledRect
    }
    
    func cropChars(observation: [VNTextObservation], orgImage:CIImage) -> CIImage?
    {

        for region:VNTextObservation in observation
        {
            guard let boxesIn = region.characterBoxes else {
                continue
            }

            if(boxesIn.count > 1 )
            {
                let scaledBox = scaleRect(orgRect: boxesIn[1].boundingBox, scaleTo: orgImage.extent)
                return orgImage.cropped(to: scaledBox)
                
            }
            else
            { return nil}
        }
        
        return nil
    }
    
}
