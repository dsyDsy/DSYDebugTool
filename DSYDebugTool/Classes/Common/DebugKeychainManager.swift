//
//  DebugKeychainManager.swift
//  DSYDebugTool
//
//  Created by code on 2026/2/3.
//

import Security
import Foundation

public class DebugKeychainManager {
    
    // MARK: - 存储字符串
    @discardableResult
    public static func save(_ value: String, forKey key: String) -> Bool {
        // 删除已有值
        if exists(key) {
            update(value, forKey: key)
        }
//        delete(key)
        
        // 准备数据
        guard let data = value.data(using: .utf8) else { return false }
        
        // 创建查询字典
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // 解锁后即可访问
        ]
        
        // 添加项目
        let status = SecItemAdd(query as CFDictionary, nil)
        
        #if DEBUG
        if status == errSecSuccess {
            print("✅ Keychain保存成功: \(key)")
        } else {
            print("❌ Keychain保存失败: \(key), 错误码: \(status)")
        }
        #endif
        
        return status == errSecSuccess
    }
    
    // MARK: - 读取字符串
    @discardableResult
    public static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            #if DEBUG
            print("❌ Keychain读取失败: \(key), 错误码: \(status)")
            #endif
            return nil
        }
        
        #if DEBUG
        print("✅ Keychain读取成功: \(key)")
        #endif
        
        return value
    }
    
    // MARK: - 删除项目
    @discardableResult
    public   static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        #if DEBUG
        if status == errSecSuccess {
            print("✅ Keychain删除成功: \(key)")
        } else if status == errSecItemNotFound {
            print("⚠️ Keychain项目不存在: \(key)")
        } else {
            print("❌ Keychain删除失败: \(key), 错误码: \(status)")
        }
        #endif
        
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - 更新项目
    @discardableResult
    public  static func update(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        #if DEBUG
        if status == errSecSuccess {
            print("✅ Keychain更新成功: \(key)")
        } else {
            print("❌ Keychain更新失败: \(key), 错误码: \(status)")
        }
        #endif
        
        return status == errSecSuccess
    }
    
    // MARK: - 检查项目是否存在
    public  static func exists(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanFalse!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        return status == errSecSuccess
    }
    
//    // MARK: - 清空所有项目（谨慎使用！）
//    @discardableResult
//    public  static func clearAll() -> Bool {
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword
//        ]
//        
//        let status = SecItemDelete(query as CFDictionary)
//        
//        #if DEBUG
//        if status == errSecSuccess {
//            print("✅ Keychain清空成功")
//        } else {
//            print("❌ Keychain清空失败, 错误码: \(status)")
//        }
//        #endif
//        
//        return status == errSecSuccess
//    }
    
    // MARK: - 获取所有存储的Key
    @discardableResult
    public static func getAllKeys() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}

