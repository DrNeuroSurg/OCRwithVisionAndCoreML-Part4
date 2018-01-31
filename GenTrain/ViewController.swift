//
//  ViewController.swift
//  GenTrain
//
//  Created by DrNeurosurg on 30.01.18.
//  Copyright © 2018 DrNeurosurg. All rights reserved.
//

import Cocoa
import Vision
import CoreImage
import AppKit
import CoreGraphics
import CoreFoundation

class ViewController: NSViewController {

    let openPanel = NSOpenPanel()

    @IBOutlet var cboFonts:NSPopUpButton!
    @IBOutlet var charList:NSTextField!
    @IBOutlet var savePath:NSTextField!
    @IBOutlet var numVariationsPerChar:NSTextField!
    @IBOutlet var stepper:NSStepper!
    @IBOutlet var progress:NSProgressIndicator!
    
    var selectedFont:NSFont?
    var detector:TextDetector?
    
    //FILTERS
    let gaussBlurFilter = CIFilter(name: "CIGaussianBlur")
    let colorGenerator = CIFilter(name: "CIConstantColorGenerator")
    let compositFilter = CIFilter(name: "CISourceOverCompositing")
    let overlayFilter = CIFilter(name: "CIDarkenBlendMode")
    let maxFilter = CIFilter(name: "CIMaximumComponent")
    let minFilter = CIFilter(name: "CIMinimumComponent")
    let grayFilter = CIFilter(name: "CIColorMonochrome")
    
    
    //MAXIMUM AND MINIMUM RATION - LIMITED BY TEXTDETECTION
    let maxRad:CGFloat = 0.15
    let minRad:CGFloat = -0.15
    let radStep:CGFloat = 0.01
    
    //THE "MAIN" FUNCTION
    
    @IBAction func generate(sender: Any?)
    {
        let steps = (maxRad - minRad) / radStep
        self.progress.maxValue = Double(steps)
        self.progress.doubleValue = 0.0
        let chrList = self.charList.stringValue
        
        let svPath = makeTrainingDir(path:self.savePath.stringValue)
        makePythonScript(savePath: self.savePath.stringValue, charList: chrList)
        let numVar = self.numVariationsPerChar.intValue
        
        DispatchQueue.global(qos: .background).async {
            self.makeTrainCharacters(charList: chrList, savePath: svPath, numVariations: Int(numVar))
        }
    }
    
    
    func makeTrainingDir(path: String)->String
    {
        let newPath = path.appending("/").appending("traindata")
        let fileManager = FileManager.default
        var isDir : ObjCBool = true
        if fileManager.fileExists(atPath: newPath, isDirectory:&isDir) {
            if isDir.boolValue {
                // file exists and is a directory
                //SKIP
            } else {
                // file exists and is not a directory
                //SKIP
            }
        } else {
            
            //CREATE DIR
            do{
                try fileManager.createDirectory(atPath: newPath, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
            
        }
        return newPath
    }
    
    func dialogOKCancel(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    @objc func makeTrainCharacters(charList:String ,savePath: String, numVariations:Int = 1)
    {

        let export = CSVExport()
        export.fileName = "OCR"
        export.directory = savePath
        export.write(text: "Class")
        
        var rad = minRad
        var charCount:Int = 0
        
        //ROTATION
        while rad < maxRad
        {

            var numChar = -1
            for character in charList
            {
                numChar = numChar + 1
               // let text = String(character).appending(" ").appending(String(character)).appending(" ").appending(String(character))  //ADD EXTRA CHARS FOR BETTER DETECTION
                let text = "\u{25FB}".appending(String(character)).appending("\u{25FB}")
                let img = self.makeTextImage(theText: text, font: self.selectedFont!)
                
                var tr = CGAffineTransform.identity
                tr = tr.rotated(by: rad) //RADIANS
                let rotatedImg = img.transformed(by: tr)
                
                //BACKGROUND WHITE - NEEDED FOR TEXT-DETECTION
                
                self.colorGenerator?.setValue(CIColor.white, forKey: "inputColor")
                let backgroundImage = self.colorGenerator?.outputImage
                
                self.compositFilter?.setValue(backgroundImage, forKey: "inputBackgroundImage")
                self.compositFilter?.setValue(rotatedImg, forKey: "inputImage")
                let composedImage = self.compositFilter?.outputImage
                
                let inImage = composedImage?.cropped(to: rotatedImg.extent)
                
                let results = self.detector?.detectText(ciImage: inImage!)
                let ciChar = self.detector?.cropChars(observation: results!, orgImage: inImage!)
                
                if(ciChar != nil)
                {
                    //WRITE PNG-IMAGE
                    var aString = String(format: "%07d", charCount) + ".PNG"
                    
                    let _ = ciChar?.saveAs28GrayPNG(url: savePath, fileName: aString)
                    export.write(text: String(format: "%d", numChar))
                    charCount += 1
                    
                    for _ in 1...numVariations
                    {
                        //WRITE VARIATED PNG-IMAGE
                        let outChar = self.makeRandomVariation(orgImage: ciChar!)
                        aString = String(format: "%07d", charCount) + ".PNG"
                        
                        let _ = outChar.saveAs28GrayPNG(url: savePath, fileName: aString)
                        export.write(text: String(format: "%d", numChar))
                        charCount += 1
                    }
                }
            }
                
                rad += self.radStep  //INCREASE ROTATION
            
            //UPDATE PROGRESSBAR
            DispatchQueue.main.async {
                self.progress.increment(by: 1)
                self.progress.displayIfNeeded()
            }
            
        }
        
        DispatchQueue.main.async {
            
            let _ = self.dialogOKCancel(question: "Finished !", text: "IMAGES GENERATED !")
            self.progress.doubleValue = 0.0
        }
        
        
    }
    
    //HELPER FOR RANDOM DOUBLES
    func randomDouble(min: Double, max: Double) -> Double
    {
        let a = Double(arc4random()) / 0xFFFFFFFF
        
        return Double(a * (max - min) + min)
    }
    
    
    //MAKE A LIST OF AVAILABLE FONTS
    func makeFontList()
    {
        cboFonts.removeAllItems()
        
        let fManage = NSFontManager()
        let fonts = fManage.availableFonts
        
        for fnt in fonts
        {
            if(fnt.starts(with: "."))
            {
                continue
            }
            cboFonts.addItem(withTitle: fnt)
        }
    }
    
    @IBAction func fontChanged(sender: Any?)
    {
        let st = cboFonts.titleOfSelectedItem
        selectedFont = NSFont(name: st!, size: 100.0)

    }

    @IBAction func stepperChanged(sender: Any?)
    {
      self.numVariationsPerChar.intValue = Int32(self.stepper.integerValue)
    }
    
    //ADD SOME RANDOM BLUR ETC.
    func makeRandomVariation(orgImage:CIImage)->CIImage
    {
        //Background
        let bgrColor = CIColor(red: CGFloat(randomDouble(min: 0.6, max: 1.0)), green: CGFloat(randomDouble(min: 0.6, max: 1.0)), blue: CGFloat(randomDouble(min: 0.6, max: 1.0)))
        colorGenerator?.setValue(bgrColor, forKey: "inputColor")
        let background = colorGenerator?.outputImage
        
        //Compose
        self.overlayFilter?.setValue(background, forKey: "inputImage")
        self.overlayFilter?.setValue(orgImage, forKey: "inputBackgroundImage")
        let overlayed = overlayFilter?.outputImage
        
        //GaussBlur
        let gaussRadius = randomDouble(min: 0.0, max: 4.5)
        self.gaussBlurFilter?.setValue(gaussRadius, forKey: "inputRadius")
        self.gaussBlurFilter?.setValue(overlayed, forKey: "inputImage")
        let gaussTemp = gaussBlurFilter?.outputImage
        
        let gauss = gaussTemp?.cropped(to: orgImage.extent)
        
        grayFilter?.setValue(gauss, forKey: "inputImage")
        let color = CIColor(red: 0.333 , green: 0.333, blue: 0.333, alpha: 1.0)
        grayFilter?.setValue(color, forKey:"inputColor");
        
        return (grayFilter?.outputImage)!
    }
    
    
    @IBAction func selectSavePath(sender: Any?)
    {
        openPanel.message = "Choose dir"
        openPanel.resolvesAliases = true
        openPanel.allowsMultipleSelection = false;
        openPanel.canChooseDirectories = true;
        openPanel.canCreateDirectories = true;
        openPanel.canChooseFiles = false;
        openPanel.allowedFileTypes = ["none"]
        openPanel.allowsOtherFileTypes = false
        
        openPanel.directoryURL =  FileManager.default.homeDirectoryForCurrentUser
        
        openPanel.begin(completionHandler:openPanelHandler)
    }
    
    //HANDLER FOR PATH-SELECTION
    func openPanelHandler(response: NSApplication.ModalResponse)
    {
        if(response == NSApplication.ModalResponse.OK)
        {
            self.savePath.stringValue = (openPanel.directoryURL?.path)!
            
        }
    }
    
    func makeTextImage(theText: String, font:NSFont) -> CIImage
    {
        let string = NSAttributedString(string: theText, attributes: [NSAttributedStringKey.font: font])
        let image = NSImage(size: string.size())
        image.lockFocus()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current!.shouldAntialias = true
        string.draw(at: NSZeroPoint)
        NSGraphicsContext.restoreGraphicsState()
        image.unlockFocus()
        
        return CIImage(data: image.tiffRepresentation!)!
        
    }
    
    
    
    func makePythonScript(savePath:String, charList:String)
    {
        let pyPath = savePath.appending("/train_OCR.py")
        let py = NSURL(fileURLWithPath: Bundle.main.path(forResource: "train_OCR", ofType: "py")!)
        var arrayOfStrings: [String]?
        do {
            let data = try String(contentsOf:py as URL, encoding: String.Encoding.utf8)
            arrayOfStrings = data.components(separatedBy: "\n")
            
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: pyPath) {
                do {
                    try "".write(toFile: pyPath, atomically: true, encoding: String.Encoding.utf8)
                } catch _ {
                }
            }
            if let fileHandle = FileHandle(forWritingAtPath: pyPath)
            {
                for st in arrayOfStrings!
                {
                    if(st.hasPrefix("output_labels"))
                    {
                        var stx = "output_labels = ["
                        for ch in charList
                        {
                            stx = stx.appending("'").appending(String(ch)).appending("',")
                        }
                       // stx =  stx.substring(to: stx.index(before: stx.endIndex))
                        stx = String(stx.characters.dropLast(1))
                        stx = stx.appending("] \n")
                        fileHandle.write(stx.data(using: String.Encoding.utf8)!)
                    }
                    else
                    {
                        let stx = st.appending("\n")
                        fileHandle.write(stx.data(using: String.Encoding.utf8)!)
                    }
                    
                }
                fileHandle.closeFile()
                
            }
            
            
        } catch let err as NSError {
            // do something with Error
            print(err)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

       
        makeFontList()
        detector = TextDetector()
        
        fontChanged(sender: self)
        self.numVariationsPerChar.intValue = Int32(self.stepper.integerValue)
        
        self.savePath.stringValue = FileManager.default.homeDirectoryForCurrentUser.path

        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

