//
//  ConcurrentSpeedTester.swift
//  ClashX Meta
//
//  Created by Claude on 2026/01/11.
//  Copyright © 2026 west2online. All rights reserved.
//

import Foundation

/// 并发控制的测速工具类
/// 用于限制同时进行的延迟测速请求数量,避免资源耗尽
class ConcurrentSpeedTester {
    /// 最大并发数
    private let maxConcurrent: Int

    /// 用于控制并发的信号量
    private let semaphore: DispatchSemaphore

    /// 并发队列,用于执行测速任务
    private let queue = DispatchQueue(label: "com.clashx.speedtest", attributes: .concurrent)

    /// 初始化并发测速器
    /// - Parameter maxConcurrent: 最大并发数,默认 20
    init(maxConcurrent: Int = 20) {
        self.maxConcurrent = maxConcurrent
        self.semaphore = DispatchSemaphore(value: maxConcurrent)
    }

    /// 批量测试代理节点延迟
    /// - Parameters:
    ///   - proxyNames: 需要测试的代理节点名称列表
    ///   - completion: 所有测速完成后的回调
    func testProxies(_ proxyNames: [String], completion: @escaping () -> Void) {
        guard !proxyNames.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()

        for proxyName in proxyNames {
            group.enter()

            // 在并发队列中异步执行测速
            queue.async { [weak self] in
                guard let self = self else {
                    group.leave()
                    return
                }

                // 等待信号量,控制并发数
                // 如果当前并发数已达上限,此处会阻塞
                self.semaphore.wait()

                // 执行实际的测速请求
                ApiRequest.getProxyDelay(proxyName: proxyName) { _ in
                    // 测速完成,释放信号量
                    self.semaphore.signal()
                    group.leave()
                }
            }
        }

        // 等待所有测速任务完成
        group.notify(queue: .main) {
            completion()
        }
    }

    /// 批量测试 Provider 健康状态
    /// - Parameters:
    ///   - providerNames: 需要测试的 Provider 名称列表
    ///   - completion: 所有测试完成后的回调
    func testProviders(_ providerNames: [String], completion: @escaping () -> Void) {
        guard !providerNames.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()

        for providerName in providerNames {
            group.enter()

            // 在并发队列中异步执行健康检查
            queue.async { [weak self] in
                guard let self = self else {
                    group.leave()
                    return
                }

                // 等待信号量,控制并发数
                self.semaphore.wait()

                // 执行实际的健康检查请求
                ApiRequest.healthCheck(proxy: providerName) {
                    // 检查完成,释放信号量
                    self.semaphore.signal()
                    group.leave()
                }
            }
        }

        // 等待所有健康检查完成
        group.notify(queue: .main) {
            completion()
        }
    }
}
