// NHK YAZILIM & TEKNOLOJİ ÇÖZÜMLERİ
// KURUMSAL VERİTABANI VE LİSANS YAPILANDIRMA MERKEZİ

enum DeploymentMode {
  cloudSaaS, // Merkezi Bulut (Supabase)
  onPremiseClient, // Müşterinin Kendi Sunucusu (Özel DB / Localhost / Kurumsal API)
}

class AppConfig {
  static const String appName = 'Mükellef Takip';
  static const String vendorName = 'MHK Yazılım';
  static const DeploymentMode currentMode = DeploymentMode.cloudSaaS;

  // 1. MERKEZİ BULUT (SaaS) BAĞLANTISI (Şu an aktif olan)
  static const String supabaseUrl = 'https://plgsxbpgbqjvrytgusjk.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_r3cPr9t6Z_wpk90b__oGIQ_gonzAyU8';

  // 2. MÜŞTERİ ÖZEL SUNUCU (ON-PREMISE) BAĞLANTISI (Satış yapıldığında aktif edilir)
  /*
  // Müşteri kendi sunucusunda Docker/Self-Hosted Supabase veya .NET Core REST API + MSSQL kullandığında
  // sadece yukarıdaki adresleri müşterinin yerel IP/Domain adresiyle değiştirmeniz yeterlidir:
  static const String supabaseUrl = 'https://muhasebe-sunucu.musterisirket.com.tr';
  static const String supabaseAnonKey = 'MUSTERI_OZEL_SUNUCU_ANAHTARI';
  static const String customDotNetApiUrl = 'https://api.musterisirket.com.tr/v1';
  static const String licenseHardwareKey = 'NHK-2026-ENT-99481-X';
  */
}
