// role_helper.dart
import 'package:flutter/material.dart';

String _normalize(String role) {
  return role.toLowerCase().replaceAll('_', ' ');
}

/// Mendapatkan level/tingkatan dari sebuah role
int roleLevel(String role) {
  switch (_normalize(role)) {
    case 'dev': return 7;
    case 'ceo': return 6;
    case 'high admin': return 5;
    case 'owner': return 4;
    case 'admin': return 3;
    case 'reseller': return 2;
    case 'vip': return 1;
    case 'member': return 0;
    default: return -1;
  }
}

/// Label role untuk UI (huruf besar semua)
String roleLabel(String role) {
  switch (_normalize(role)) {
    case 'dev': return 'DEV';
    case 'ceo': return 'CEO';
    case 'high admin': return 'HIGH ADMIN';
    case 'owner': return 'OWNER';
    case 'admin': return 'ADMIN';
    case 'reseller': return 'RESELLER';
    case 'vip': return 'VIP';
    case 'member': return 'MEMBER';
    default: return role.toUpperCase();
  }
}

/// Role yang dapat dibuat oleh currentRole (dalam bentuk normal)
List<String> creatableRoles(String currentRole) {
  switch (_normalize(currentRole)) {
    case 'dev':
      return ['ceo', 'high admin', 'owner', 'admin', 'reseller', 'vip', 'member'];
    case 'ceo':
      return ['high admin', 'owner', 'admin', 'reseller', 'vip', 'member'];
    case 'high admin':
      return ['owner', 'admin', 'reseller', 'vip', 'member'];
    case 'owner':
      return ['admin', 'reseller', 'vip', 'member'];
    case 'admin':
      return ['reseller', 'vip', 'member'];
    case 'reseller':
      return ['member'];
    default:
      return [];
  }
}

/// Cek apakah currentRole dapat membuat targetRole
bool canCreateRole(String currentRole, String targetRole) {
  final targetNorm = _normalize(targetRole);
  return creatableRoles(currentRole).contains(targetNorm);
}

/// Cek apakah currentRole dapat menghapus targetRole
bool canDeleteUser(String currentRole, String targetRole) {
  final currentLvl = roleLevel(currentRole);
  final targetLvl = roleLevel(targetRole);
  if (targetLvl >= currentLvl) return false;
  // Khusus dev: bisa hapus semua role selain dev sendiri
  if (_normalize(currentRole) == 'dev' && _normalize(targetRole) != 'dev') return true;
  return targetLvl < currentLvl;
}

/// Cek apakah currentRole dapat mengedit (extend durasi) targetRole
bool canEditUser(String currentRole, String targetRole) {
  return canDeleteUser(currentRole, targetRole);
}

/// Maksimal hari yang dapat diberikan oleh currentRole
int maxDays(String currentRole) {
  switch (_normalize(currentRole)) {
    case 'dev': return 9999;
    case 'ceo': return 365;
    case 'high admin': return 180;
    case 'owner': return 90;
    case 'admin': return 60;
    case 'reseller': return 30;
    default: return 0;
  }
}

/// Daftar semua role (untuk filter dropdown)
List<String> getAllRoles() {
  return ['dev', 'ceo', 'high admin', 'owner', 'admin', 'reseller', 'vip', 'member'];
}

/// Mendapatkan role yang lebih tinggi dari role tertentu
List<String> getHigherRoles(String role) {
  final currentLvl = roleLevel(role);
  return getAllRoles().where((r) => roleLevel(r) > currentLvl).toList();
}

/// Mendapatkan role yang lebih rendah dari role tertentu
List<String> getLowerRoles(String role) {
  final currentLvl = roleLevel(role);
  return getAllRoles().where((r) => roleLevel(r) < currentLvl).toList();
}

/// Cek apakah role valid
bool isValidRole(String role) {
  return getAllRoles().contains(_normalize(role));
}

/// Warna role untuk UI
Color getRoleColor(String role) {
  switch (_normalize(role)) {
    case 'dev': return const Color(0xFF9C27B0);
    case 'ceo': return const Color(0xFF00BCD4);
    case 'high admin': return const Color(0xFFFF9800);
    case 'owner': return const Color(0xFFD4AF37);
    case 'admin': return const Color(0xFFF44336);
    case 'reseller': return const Color(0xFFFF6B35);
    case 'vip': return const Color(0xFF4CAF50);
    case 'member': return const Color(0xFF9E9E9E);
    default: return const Color(0xFF9E9E9E);
  }
}

/// Ikon role untuk UI
IconData getRoleIcon(String role) {
  switch (_normalize(role)) {
    case 'dev': return Icons.code;
    case 'ceo': return Icons.celebration;
    case 'high admin': return Icons.security;
    case 'owner': return Icons.workspace_premium;
    case 'admin': return Icons.admin_panel_settings;
    case 'reseller': return Icons.storefront;
    case 'vip': return Icons.star;
    default: return Icons.person;
  }
}

/// Deskripsi role
String getRoleDescription(String role) {
  switch (_normalize(role)) {
    case 'dev': return 'Developer - Akses penuh ke semua fitur';
    case 'ceo': return 'CEO - Bisa membuat High Admin ke bawah';
    case 'high admin': return 'High Admin - Bisa membuat Owner ke bawah';
    case 'owner': return 'Owner - Bisa membuat Admin ke bawah';
    case 'admin': return 'Admin - Bisa membuat Reseller ke bawah';
    case 'reseller': return 'Reseller - Bisa membuat Member';
    case 'vip': return 'VIP - Tidak bisa membuat akun';
    case 'member': return 'Member - Tidak bisa membuat akun';
    default: return 'Role tidak dikenal';
  }
}