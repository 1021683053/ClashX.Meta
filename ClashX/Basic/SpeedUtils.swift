//
//  SpeedUtils.swift
//  ClashX
//
//  Created by yicheng on 2023/7/6.
//  Copyright © 2023 west2online. All rights reserved.
//

import Foundation

enum SpeedUtils {
    private static let units = ["KB", "MB", "GB", "TB", "PB", "EB"]

    static func getSpeedString(for byte: Int) -> String {
        return getNetString(for: byte).appending("/s")
    }

    static func getNetString(for byte: Int) -> String {
        var value = Double(max(byte, 0)) / 1024.0
        var unitIndex = 0

        while value >= 999.5, unitIndex < units.count - 1 {
            value /= 1024.0
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(Int(value))\(units[unitIndex])"
        }

        if value < 99.95 {
            return String(format: "%.1f%@", value, units[unitIndex])
        }

        return String(format: "%.0f%@", value, units[unitIndex])
    }
}
