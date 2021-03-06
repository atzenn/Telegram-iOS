import Foundation
import UIKit
import SwiftSignalKit

private final class PresentationsResourceCacheHolder {
    var images: [Int32: UIImage] = [:]
}

private final class PresentationsResourceAnyCacheHolder {
    var objects: [Int32: AnyObject] = [:]
}

public final class PresentationsResourceCache {
    private let imageCache = Atomic<PresentationsResourceCacheHolder>(value: PresentationsResourceCacheHolder())
    private let objectCache = Atomic<PresentationsResourceAnyCacheHolder>(value: PresentationsResourceAnyCacheHolder())
    
    public func image(_ key: Int32, _ theme: PresentationTheme, _ generate: (PresentationTheme) -> UIImage?) -> UIImage? {
        let result = self.imageCache.with { holder -> UIImage? in
            return holder.images[key]
        }
        if let result = result {
            return result
        } else {
            if let image = generate(theme) {
                self.imageCache.with { holder -> Void in
                    holder.images[key] = image
                }
                return image
            } else {
                return nil
            }
        }
    }
    
    public func object(_ key: Int32, _ theme: PresentationTheme, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        let result = self.objectCache.with { holder -> AnyObject? in
            return holder.objects[key]
        }
        if let result = result {
            return result
        } else {
            if let object = generate(theme) {
                self.objectCache.with { holder -> Void in
                    holder.objects[key] = object
                }
                return object
            } else {
                return nil
            }
        }
    }
}
