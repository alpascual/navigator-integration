/*
 Copyright 2016 Esri
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

private extension String {
    private func queryArgumentEncodedString() -> String? {
        let charSet = NSCharacterSet.URLQueryAllowedCharacterSet().mutableCopy() as! NSMutableCharacterSet
        charSet.removeCharactersInString("&")

        return stringByAddingPercentEncodingWithAllowedCharacters(charSet)
    }
}

public final class NavigatorURLScheme {

    public static let scheme = "arcgis-navigator:"
    
    public static var canOpen: Bool {
        return UIApplication.sharedApplication().canOpenURL(NSURL(string: scheme)!)
    }

    public struct URLSchemeError: ErrorType {
        let unencodableString: String
    }

    public enum LocationType {

        case WGS84(point: AGSPoint)
        case Address(String)

        public func queryArgument() throws -> String {
            switch self {
            case .WGS84(point: let point):
                return "\(point.y),\(point.x)"
            case .Address(let address):
                if let address = address.queryArgumentEncodedString() {
                    return address
                } else {
                    throw URLSchemeError(unencodableString:address)
                }
            }
        }
    }

    private enum StopType: String {

        case Start = "start"
        case Stop = "stop"
    }

    public let optimize: Bool

    public let navigate: Bool

    private var start: NavigatorStop?

    private var stops = [NavigatorStop]()

    private var callback: Callback?

    public init(optimizeRoute optimize: Bool = false, startNavigating navigate: Bool = false) {
        self.optimize = optimize
        self.navigate = navigate
    }

    public func setStartAtLocation(location: LocationType, withName name: String? = nil) {
        start = NavigatorStop(location: location, name: name, stopType: .Start)
    }

    public func addStopAtLocation(location: LocationType, withName name:String? = nil) {
        stops.append(NavigatorStop(location: location, name: name, stopType: .Stop))
    }

    public func setCallbackScheme(scheme: String, prompt: String? ) {
        callback = Callback(scheme: scheme, prompt: prompt)
    }

    public func generateURL() throws -> NSURL? {

        var stringBuilder = "\(NavigatorURLScheme.scheme)//?optimize=\(optimize ? "true" : "false")&navigate=\(navigate ? "true" : "false")"

        if let start = try start?.encodeStop() {
            stringBuilder += start
        }

        if !stops.isEmpty {
            let encodedStops = try stops.flatMap({ return try $0.encodeStop() }).joinWithSeparator("")
            stringBuilder += encodedStops
        }

        if let callback = try callback?.encodedArgumentString() {
            stringBuilder += callback
        }

        return NSURL(string: stringBuilder)
    }

    private struct NavigatorStop {

        let location: LocationType
        let name: String?
        let stopType: StopType

        public init(location: LocationType,  name: String?, stopType: StopType) {
            self.location = location
            self.name = name
            self.stopType = stopType
        }

        private func encodeStop() throws -> String {

            let nameArgument: String

            if let name = name {
                if let encoded = name.queryArgumentEncodedString() {
                    nameArgument = "&\(stopType.rawValue)name=\(encoded)"
                } else {
                    throw URLSchemeError(unencodableString: name)
                }
            } else {
                nameArgument = ""
            }

            return "&\(stopType.rawValue)=\(try location.queryArgument())\(nameArgument)"
        }
    }

    private struct Callback {

        let callbackScheme: String
        let callbackPrompt: String?

        init(scheme: String, prompt: String?) {
            callbackScheme = scheme
            callbackPrompt = prompt
        }

        public func encodedArgumentString() throws -> String {

            let encodedScheme: String
            if let encoded = callbackScheme.queryArgumentEncodedString() {
                encodedScheme = "&callback=\(encoded)"
            } else {
                throw URLSchemeError(unencodableString: callbackScheme)
            }

            let encodedPrompt: String
            if let prompt = callbackPrompt {
                if let encoded = prompt.queryArgumentEncodedString() {
                    encodedPrompt = "&callbackprompt=\(encoded)"
                } else {
                    throw URLSchemeError(unencodableString: prompt)
                }
            } else {
                encodedPrompt = ""
            }
            
            return "\(encodedScheme)\(encodedPrompt)"
        }
    }
}
