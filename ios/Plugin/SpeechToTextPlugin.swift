import Foundation
import Capacitor
import Speech
import UIKit
import os.log
import Try

public enum SwiftSpeechToTextCallbackMethods: String {
    case textRecognition
    case notifyStatus
    case notifyError
    case soundLevelChange
}

public enum ListenMode: Int {
    case deviceDefault = 0
    case dictation = 1
    case search = 2
    case confirmation = 3
}

struct SpeechRecognitionWords : Codable {
    let recognizedWords: String
    let confidence: Decimal
}

public enum SpeechToTextStatus: String {
    case listening
    case notListening
    case unavailable
    case available
    case done
    case doneNoResult
}

struct SpeechRecognitionResult : Codable {
    let alternates: [SpeechRecognitionWords]
    let finalResult: Bool
}

public enum SpeechToTextErrors: String {
    case onDeviceError
    case noRecognizerError
    case listenFailedError
    case missingOrInvalidArg
}

struct SpeechRecognitionError : Codable {
    let errorMsg: String
    let permanent: Bool
}

enum SpeechToTextError: Error {
    case runtimeError(String)
}

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(SpeechToTextPlugin)
public class SpeechToTextPlugin: CAPPlugin {
    private let implementation = SpeechToText()
    
    private var speechRecognizer : SFSpeechRecognizer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var previousLocale: Locale?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest : SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask : SFSpeechRecognitionTask?
    private var onDeviceStatus: Bool = false
    private var currentTask: SFSpeechRecognitionTask?
    private var inputNode: AVAudioInputNode?
    private var listening = false
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var listeningSound: AVAudioPlayer?
    private var successSound: AVAudioPlayer?
    private var cancelSound: AVAudioPlayer?
    private var rememberedAudioCategory: AVAudioSession.Category?
    private var rememberedAudioCategoryOptions: AVAudioSession.CategoryOptions?
    private var onPlayEnd: (() -> Void)?
    private var returnPartialResults: Bool = true
    private var failedListen: Bool = false
    private var stopping = false
    private let jsonEncoder = JSONEncoder()
    private let busForNodeTap = 0
    private let speechBufferSize: AVAudioFrameCount = 1024
    
    private let pluginLog = OSLog(subsystem: "com.kodxsytem.speechrecognition", category: "plugin")

    @objc func hasPermission(_ call: CAPPluginCall) {
        let status: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
        let speechAuthGranted : Bool = (status == SFSpeechRecognizerAuthorizationStatus.authorized)
        
        if (!speechAuthGranted) {
            call.resolve([
                "permission": false
            ])
            return
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { (granted: Bool) in
            call.resolve([
                "permission": granted
            ])
        }
    }
    
    @objc func initialize(_ call: CAPPluginCall) {
        var success = false
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case SFSpeechRecognizerAuthorizationStatus.notDetermined:
            SFSpeechRecognizer.requestAuthorization({(status)->Void in
                success = status == SFSpeechRecognizerAuthorizationStatus.authorized
                if ( success ) {
                    self.audioSession.requestRecordPermission({(granted: Bool)-> Void in
                        if granted {
                            self.setupSpeechRecognition(call)
                        } else{
                            call.resolve(["available": false]);
                        }
                    })
                }
                else {
                    call.resolve(["available": false]);
                }
            });
        case SFSpeechRecognizerAuthorizationStatus.denied:
            os_log("Permission permanently denied", log: self.pluginLog, type: .info)
            call.resolve(["available": false]);
        case SFSpeechRecognizerAuthorizationStatus.restricted:
            os_log("Device restriction prevented initialize", log: self.pluginLog, type: .info)
            call.resolve(["available": false]);
        default:
            os_log("Has permissions continuing with setup", log: self.pluginLog, type: .debug)
            self.setupSpeechRecognition(call)
        }
    }
    
    private func setupSpeechRecognition( _ call: CAPPluginCall) {
        setupRecognizerForLocale( locale: Locale.current )
        guard speechRecognizer != nil else {
            call.resolve(["available": false]);
            return
        }
        if #available(iOS 13.0, *), let localRecognizer = speechRecognizer {
            onDeviceStatus = localRecognizer.supportsOnDeviceRecognition
        }
        speechRecognizer?.delegate = self
        inputNode = audioEngine.inputNode
        guard inputNode != nil else {
            os_log("Error no input node", log: pluginLog, type: .error)
            call.resolve(["available": false]);
            return
        }
        setupListeningSound()
        
        call.resolve(["available": true]);
    }
    
    fileprivate func setupListeningSound() {
        listeningSound = loadSound("assets/sounds/speech_to_text_listening.m4r")
        successSound = loadSound("assets/sounds/speech_to_text_stop.m4r")
        cancelSound = loadSound("assets/sounds/speech_to_text_cancel.m4r")
    }
    
    fileprivate func loadSound( _ assetPath: String ) -> AVAudioPlayer? {
        var player: AVAudioPlayer? = nil
//        let soundKey = registrar.lookupKey(forAsset: assetPath )
//        guard !soundKey.isEmpty else {
//            return player
//        }
//        if let soundPath = Bundle.main.path(forResource: soundKey, ofType:nil) {
//            let soundUrl = URL(fileURLWithPath: soundPath )
//            do {
//                player = try AVAudioPlayer(contentsOf: soundUrl )
//                player?.delegate = self
//            } catch {
//                // no audio
//            }
//        }
        return player
    }
    
    private func setupRecognizerForLocale( locale: Locale ) {
        if ( previousLocale == locale ) {
            return
        }
        previousLocale = locale
        speechRecognizer = SFSpeechRecognizer( locale: locale )
    }
    
    @objc func stop(_ call: CAPPluginCall) {
        if ( !listening ) {
            call.resolve(["stopped": false])
            return
        }
        stopping = true
        stopAllPlayers()
        self.currentTask?.finish()
        if let sound = successSound {
            onPlayEnd = {() -> Void in
                self.stopCurrentListen( )
                call.resolve(["stopped": true])
                return
            }
            sound.play()
        }
        else {
            stopCurrentListen( )
            call.resolve(["stopped": true])
        }
    }
    
    @objc func cancel(_ call: CAPPluginCall) {
        if ( !listening ) {
            call.resolve(["cancelled": false])
            return
        }
        stopping = true
        stopAllPlayers()
        self.currentTask?.cancel()
        if let sound = cancelSound {
            onPlayEnd = {() -> Void in
                self.stopCurrentListen( )
                call.resolve(["cancelled": true])
                return
            }
            sound.play()
        }
        else {
            stopCurrentListen( )
            call.resolve(["cancelled": true])
        }
    }
    
    private func stopAllPlayers() {
        cancelSound?.stop()
        successSound?.stop()
        listeningSound?.stop()
    }
    
    @objc func locales(_ call: CAPPluginCall) {
        var localeNames = [String]();
        let locales = SFSpeechRecognizer.supportedLocales();
        var currentLocaleId = Locale.current.identifier
        if Locale.preferredLanguages.count > 0 {
            currentLocaleId = Locale.preferredLanguages[0]
        }
        if let idName = buildIdNameForLocale(forIdentifier: currentLocaleId ) {
            localeNames.append(idName)
        }
        for locale in locales {
            if ( locale.identifier == currentLocaleId) {
                continue
            }
            if let idName = buildIdNameForLocale(forIdentifier: locale.identifier ) {
                localeNames.append(idName)
            }
        }
        DispatchQueue.main.async {
            call.resolve(["languages": localeNames])
        }
    }
    
    @objc func listen(_ call: CAPPluginCall) {
//        let onDevice = false
//        let partialResults = call.getBool("partialResults") ?? false
//        let localeStr = call.getString("localeStr")
//        let sampleRate = call.getInt("sampleRate", 0)
//        let listenMode = ListenMode.confirmation
        guard let partialResults = call.getBool("partialResults"), let onDevice = call.getBool("onDevice"), let listenModeIndex = call.getInt("listenMode"), let sampleRate = call.getInt("sampleRate")
        else {
            DispatchQueue.main.async {
                call.reject("Missing arg partialResults, onDevice, listenMode, and sampleRate are required",  SpeechToTextErrors.missingOrInvalidArg.rawValue)
            }
            return
        }
        var localeStr: String? = nil
        if let localeParam = call.getString("localeId") {
            localeStr = localeParam
        }
        guard let listenMode = ListenMode(rawValue: listenModeIndex) else {
            DispatchQueue.main.async {
                call.reject("invalid value for listenMode, must be 0-2, was \(listenModeIndex)", SpeechToTextErrors.missingOrInvalidArg.rawValue)
            }
            return
        }
        listenForSpeech(call, listenMode: listenMode, localeStr: localeStr, partialResults: partialResults, onDevice: onDevice,   sampleRate: sampleRate )
    }
    
    private func listenForSpeech( _ call: CAPPluginCall, listenMode: ListenMode, localeStr: String?, partialResults: Bool, onDevice: Bool, sampleRate: Int ) {
        if ( nil != currentTask || listening ) {
            call.resolve(["started": false]);
            return
        }
        do {
            failedListen = false
            stopping = false
            returnPartialResults = partialResults
            setupRecognizerForLocale(locale: getLocale(localeStr))
            guard let localRecognizer = speechRecognizer else {
                call.reject("Failed to create speech recognizer", SpeechToTextErrors.noRecognizerError.rawValue)
                return
            }
            if ( onDevice ) {
                if #available(iOS 13.0, *), !localRecognizer.supportsOnDeviceRecognition {
                    call.reject("on device recognition is not supported on this device", SpeechToTextErrors.onDeviceError.rawValue)
                }
            }
            rememberedAudioCategory = self.audioSession.category
            rememberedAudioCategoryOptions = self.audioSession.categoryOptions
            try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord, options: [.defaultToSpeaker,.allowBluetooth,.allowBluetoothA2DP])
            //            try self.audioSession.setMode(AVAudioSession.Mode.measurement)
            if ( sampleRate > 0 ) {
                try self.audioSession.setPreferredSampleRate(Double(sampleRate))
            }
            try self.audioSession.setMode(AVAudioSession.Mode.default)
            try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            if let sound = listeningSound {
                self.onPlayEnd = {()->Void in
                    if ( !self.failedListen ) {
                        self.listening = true
                        self.invokeCapacitor(SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.listening.rawValue])

                    }
                }
                sound.play()
            }

            self.audioEngine.reset();
            if(inputNode?.inputFormat(forBus: 0).channelCount == 0){
                throw SpeechToTextError.runtimeError("Not enough available inputs.")
            }
            self.currentRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let currentRequest = self.currentRequest else {
                call.resolve(["started": false]);
                return
            }
            currentRequest.shouldReportPartialResults = true
            if #available(iOS 13.0, *), onDevice {
                currentRequest.requiresOnDeviceRecognition = true
            }
            switch listenMode {
            case ListenMode.dictation:
                currentRequest.taskHint = SFSpeechRecognitionTaskHint.dictation
                break
            case ListenMode.search:
                currentRequest.taskHint = SFSpeechRecognitionTaskHint.search
                break
            case ListenMode.confirmation:
                currentRequest.taskHint = SFSpeechRecognitionTaskHint.confirmation
                break
            default:
                break
            }
            
            self.currentTask = self.speechRecognizer?.recognitionTask(with: currentRequest, delegate: self )
            let recordingFormat = inputNode?.outputFormat(forBus: self.busForNodeTap)
            let theSampleRate = audioSession.sampleRate
            let fmt = AVAudioFormat(commonFormat: recordingFormat!.commonFormat, sampleRate: theSampleRate, channels: recordingFormat!.channelCount, interleaved: recordingFormat!.isInterleaved)
            try trap {
                self.inputNode?.installTap(onBus: self.busForNodeTap, bufferSize: self.speechBufferSize, format: fmt) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                    currentRequest.append(buffer)
//                    self.updateSoundLevel( buffer: buffer )
                }
            }
        //    if ( inErrorTest ){
        //        throw SpeechToTextError.runtimeError("for testing only")
        //    }
            self.audioEngine.prepare()
            try self.audioEngine.start()
            if nil == listeningSound {
                listening = true
                self.invokeCapacitor( SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.listening.rawValue] )
            }
            call.resolve(["started": true]);
        }
        catch {
            failedListen = true
            os_log("Error starting listen: %{PUBLIC}@", log: pluginLog, type: .error, error.localizedDescription)
            self.invokeCapacitor( SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.notListening.rawValue] )
            stopCurrentListen()
            call.resolve(["started": false]);
            // ensure the not listening signal is sent in the error case
            let speechError = SpeechRecognitionError(errorMsg: "error_listen_failed", permanent: true )
            do {
                let errorResult = try jsonEncoder.encode(speechError)
                invokeCapacitor( SwiftSpeechToTextCallbackMethods.notifyError, data: ["error": String( data:errorResult, encoding: .utf8) ?? ""] )
                invokeCapacitor( SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.doneNoResult.rawValue] )
            } catch {
                os_log("Could not encode JSON", log: pluginLog, type: .error)
            }
        }
    }
    
    private func stopCurrentListen( ) {
        self.currentRequest?.endAudio()
        stopAllPlayers()
        do {
            try trap {
                self.audioEngine.stop()
            }
        }
        catch {
            os_log("Error stopping engine: %{PUBLIC}@", log: pluginLog, type: .error, error.localizedDescription)
        }
        do {
            try trap {
                self.inputNode?.removeTap(onBus: self.busForNodeTap);
            }
        }
        catch {
            os_log("Error removing trap: %{PUBLIC}@", log: pluginLog, type: .error, error.localizedDescription)
        }
        do {
            if let rememberedAudioCategory = rememberedAudioCategory, let rememberedAudioCategoryOptions = rememberedAudioCategoryOptions {
                try self.audioSession.setCategory(rememberedAudioCategory,options: rememberedAudioCategoryOptions)
            }
        }
        catch {
            os_log("Error stopping listen: %{PUBLIC}@", log: pluginLog, type: .error, error.localizedDescription)
        }
        do {
            try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
        catch {
            os_log("Error deactivation: %{PUBLIC}@", log: pluginLog, type: .info, error.localizedDescription)
        }
        self.invokeCapacitor( SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.done.rawValue] )

        currentRequest = nil
        currentTask = nil
        onPlayEnd = nil
        listening = false
        stopping = false
    }
    
    private func updateSoundLevel( buffer: AVAudioPCMBuffer) {
        guard
            let channelData = buffer.floatChannelData
            else {
                return
        }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride).map{ channelDataValue[$0] }
        let frameLength = Float(buffer.frameLength)
        let rms = sqrt(channelDataValueArray.map{ $0 * $0 }.reduce(0, +) / frameLength )
        let avgPower = 20 * log10(rms)
        self.invokeCapacitor( SwiftSpeechToTextCallbackMethods.soundLevelChange, data: ["soundLevel": avgPower] )
    }
    
    private func handleResult( _ transcriptions: [SFTranscription], isFinal: Bool ) {
        if ( !isFinal && !returnPartialResults ) {
            return
        }
        var speechWords: [SpeechRecognitionWords] = []
        for transcription in transcriptions {
            let words: SpeechRecognitionWords = SpeechRecognitionWords(recognizedWords: transcription.formattedString, confidence: confidenceIn( transcription))
            speechWords.append( words )
        }
        let speechInfo = SpeechRecognitionResult(alternates: speechWords, finalResult: isFinal )
        do {
            let speechMsg = try jsonEncoder.encode(speechInfo)
            if let speechStr = String( data:speechMsg, encoding: .utf8) {
                print(speechStr)
                os_log("Encoded JSON result: %{PUBLIC}@", log: pluginLog, type: .debug, speechStr )
                self.invokeCapacitor( SwiftSpeechToTextCallbackMethods.textRecognition, data: ["speechString": speechStr] )
            }
        } catch {
            os_log("Could not encode JSON", log: pluginLog, type: .error)
        }
    }
    
    private func confidenceIn( _ transcription: SFTranscription ) -> Decimal {
        guard ( transcription.segments.count > 0 ) else {
            return 0;
        }
        var totalConfidence: Float = 0.0;
        for segment in transcription.segments {
            totalConfidence += segment.confidence
        }
        let avgConfidence: Float = totalConfidence / Float(transcription.segments.count )
        let confidence: Float = (avgConfidence * 1000).rounded() / 1000
        return Decimal( string: String( describing: confidence ) )!
    }
    
    private func getLocale( _ localeStr: String? ) -> Locale {
        guard let aLocaleStr = localeStr else {
            return Locale.current
        }
        let locale = Locale(identifier: aLocaleStr)
        return locale
    }
    
    private func buildIdNameForLocale( forIdentifier: String ) -> String? {
        var idName: String?
        if let name = Locale.current.localizedString(forIdentifier: forIdentifier ) {
            let sanitizedName = name.replacingOccurrences(of: ":", with: " ")
            idName = "\(forIdentifier):\(sanitizedName)"
        }
        return idName
    }
    
    private func invokeCapacitor(_ method: SwiftSpeechToTextCallbackMethods, data: [String: Any]) {
        os_log("invokeCapacitor %{PUBLIC}@", log: pluginLog, type: .debug, data.keys.description )
        DispatchQueue.main.async {
            self.notifyListeners(method.rawValue, data: data )
        }
    }
}

@available(iOS 10.0, *)
extension SpeechToTextPlugin : SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        let availability = available ? SpeechToTextStatus.available.rawValue : SpeechToTextStatus.unavailable.rawValue
        
        os_log("Availability changed: %{PUBLIC}@", log: pluginLog, type: .debug, availability)
        invokeCapacitor(SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": availability])
    }
}

@available(iOS 10.0, *)
extension SpeechToTextPlugin : SFSpeechRecognitionTaskDelegate {
    public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        // Do nothing for now
    }
    
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        reportError(source: "FinishedReadingAudio", error: task.error)
        os_log("Finished reading audio", log: pluginLog, type: .debug )
        invokeCapacitor(SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.notListening.rawValue])
    }
    
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        reportError(source: "TaskWasCancelled", error: task.error)
        os_log("Canceled reading audio", log: pluginLog, type: .debug )
        invokeCapacitor(SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.notListening.rawValue])
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        reportError(source: "FinishSuccessfully", error: task.error)
        os_log("FinishSuccessfully", log: pluginLog, type: .debug )
        if ( !successfully ) {
            invokeCapacitor(SwiftSpeechToTextCallbackMethods.notifyStatus, data: ["status": SpeechToTextStatus.doneNoResult.rawValue])
            if let err = task.error as NSError? {
                var errorMsg: String
                switch err.code {
                case 201:
                    errorMsg = "error_speech_recognizer_disabled"
                case 203:
                    errorMsg = "error_retry"
                case 1110:
                    errorMsg = "error_no_match"
                default:
                    errorMsg = "error_unknown (\(err.code))"
                }
                self.notifyListeners("onError", data: ["error": errorMsg])
                let speechError = SpeechRecognitionError(errorMsg: errorMsg, permanent: true )
                do {
                    let errorResult = try jsonEncoder.encode(speechError)
                    invokeCapacitor(SwiftSpeechToTextCallbackMethods.notifyError, data: ["error": String(data:errorResult, encoding: .utf8) ?? ""])
                } catch {
                    os_log("Could not encode JSON", log: pluginLog, type: .error)
                }
            }
        }
        if !stopping {
            if let sound = successfully ? successSound : cancelSound {
                onPlayEnd = {() -> Void in
                    self.stopCurrentListen( )
                }
                sound.play()
            }
            else {
                stopCurrentListen( )
            }
        }
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        os_log("HypothesizeTranscription", log: pluginLog, type: .debug )
        reportError(source: "HypothesizeTranscription", error: task.error)
        handleResult( [transcription], isFinal: false )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        reportError(source: "FinishRecognition", error: task.error)
        os_log("FinishRecognition %{PUBLIC}@", log: pluginLog, type: .debug, recognitionResult.isFinal.description )
        let isFinal = recognitionResult.isFinal
        handleResult( recognitionResult.transcriptions, isFinal: isFinal )
    }
    
    private func reportError( source: String, error: Error?) {
        if ( nil != error) {
            os_log("%{PUBLIC}@ with error: %{PUBLIC}@", log: pluginLog, type: .debug, source, error.debugDescription)
        }
    }
}

@available(iOS 10.0, *)
extension SpeechToTextPlugin : AVAudioPlayerDelegate {
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                            successfully flag: Bool) {
        if let playEnd = self.onPlayEnd {
            playEnd()
        }
    }
}

