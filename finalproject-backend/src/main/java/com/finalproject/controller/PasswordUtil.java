package com.finalproject.controller;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

public final class PasswordUtil {

    private static final String ALGO = "pbkdf2";
    private static final String PBKDF2_ALGO = "PBKDF2WithHmacSHA256";

    // ปรับได้ตามต้องการ
    private static final int ITERATIONS = 120_000;     // ความแข็งแรง
    private static final int SALT_LEN   = 16;          // 128-bit
    private static final int KEY_LEN    = 32;          // 256-bit

    private PasswordUtil() {}

    /** สร้างรหัสผ่านสำหรับเก็บลง DB: รูปแบบ pbkdf2$<iter>$<saltBase64>$<hashBase64> */
    public static String createPassword(String rawPassword) {
        byte[] salt = randomSalt(SALT_LEN);
        byte[] hash = pbkdf2(rawPassword, salt, ITERATIONS, KEY_LEN);
        return format(ALGO, ITERATIONS, salt, hash);
    }

    /** ตรวจสอบรหัสผ่านจากผู้ใช้กับค่าที่เก็บใน DB (รูปแบบด้านบน) */
    public static boolean verifyPassword(String rawPassword, String stored) {
        if (rawPassword == null || stored == null) return false;

        try {
            // รูปแบบ: algo$iter$salt$hash
            String[] parts = stored.split("\\$");
            if (parts.length != 4) return false;

            String algo = parts[0];
            int iter = Integer.parseInt(parts[1]);
            byte[] salt = Base64.getDecoder().decode(parts[2]);
            byte[] expected = Base64.getDecoder().decode(parts[3]);

            if (!ALGO.equalsIgnoreCase(algo)) return false;

            byte[] actual = pbkdf2(rawPassword, salt, iter, expected.length);
            return MessageDigest.isEqual(actual, expected);
        } catch (Exception e) {
            return false;
        }
    }

    /* -------------------- helpers -------------------- */

    private static byte[] randomSalt(int len) {
        byte[] salt = new byte[len];
        new SecureRandom().nextBytes(salt);
        return salt;
    }

    private static byte[] pbkdf2(String password, byte[] salt, int iterations, int keyLen) {
        try {
            PBEKeySpec spec = new PBEKeySpec(password.toCharArray(), salt, iterations, keyLen * 8);
            SecretKeyFactory skf = SecretKeyFactory.getInstance(PBKDF2_ALGO);
            return skf.generateSecret(spec).getEncoded();
        } catch (Exception e) {
            throw new IllegalStateException("PBKDF2 error", e);
        }
    }

    private static String format(String algo, int iter, byte[] salt, byte[] hash) {
        return algo
                + "$" + iter
                + "$" + Base64.getEncoder().encodeToString(salt)
                + "$" + Base64.getEncoder().encodeToString(hash);
    }

    /* ---------- (ทางเลือก) รองรับผู้ใช้เก่าแบบ plaintext/sha256 ---------- */

    /** hash sha256(password + salt) – ใช้เฉพาะการย้ายข้อมูลเก่า */
    public static String sha256(String text) {
        try {
            MessageDigest d = MessageDigest.getInstance("SHA-256");
            byte[] h = d.digest(text.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(h.length * 2);
            for (byte b : h) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) sb.append('0');
                sb.append(hex);
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
