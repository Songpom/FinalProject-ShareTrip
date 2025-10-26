package com.finalproject.controller; // หรือ package ที่คุณใช้อยู่

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import java.time.*;
import java.time.format.DateTimeFormatter;

@Component
public class CheckSlipController {

    // ปรับค่าให้ตรงกับของโปรเจ็กต์ (ถ้าคุณมีคอนสแตนต์ส่วนกลางอยู่แล้วให้ลบอันนี้ทิ้ง)
    public static final ZoneId ZONE_TH = ZoneId.of("Asia/Bangkok");
    public static final int WINDOW_MINUTES = 60; // หน้าต่างเวลาอนุโลม
    public static final int SKEW_MINUTES   = 5;  // เผื่อ clock skew

    private final ObjectMapper mapper = new ObjectMapper();
    private final HttpClient http = HttpClient.newHttpClient();

    /** โครงสร้างผลลัพธ์ */
    public static class SlipCheckResult {
        public final JsonNode data;
        public final double amountFromSlip;
        public final Instant txChosen;        // เวลาที่เลือกใช้
        public final long bestDiffMinutes;    // ความต่างนาที (น้อยสุด)
        public SlipCheckResult(JsonNode data, double amountFromSlip, Instant txChosen, long bestDiffMinutes) {
            this.data = data;
            this.amountFromSlip = amountFromSlip;
            this.txChosen = txChosen;
            this.bestDiffMinutes = bestDiffMinutes;
        }
    }

    /** ข้อผิดพลาดพร้อม HTTP Status เอาไปสร้าง ResponseEntity ได้สะดวก */
    public static class SlipCheckException extends RuntimeException {
        public final HttpStatus status;
        public SlipCheckException(String message, HttpStatus status) {
            super(message);
            this.status = status;
        }
    }

    /**
     * ตรวจสลิปรวม: เรียก API, ตรวจ amount, ตรวจ 4 ตัวท้ายผู้รับ, ตรวจเวลา
     *
     * @param amountRequested   จำนวนเงินที่ระบบคาดหวัง
     * @param base64WithPrefix  รูปแบบ "data:<mime>;base64,<...>"
     * @param expectedLast4     เลข 4 ตัวท้าย "ผู้รับเงิน" ที่คาดหวัง (owner หรือสมาชิก ขึ้นกับ use-case)
     * @return                  SlipCheckResult
     * @throws SlipCheckException เมื่อไม่ผ่านเงื่อนไข (มีข้อความไทยพร้อม HttpStatus)
     */
    public SlipCheckResult verifySlip(double amountRequested, String base64WithPrefix, String expectedLast4) {
        try {
            // 1) เรียก API ภายนอก
            String jsonPayload = "{\"img\":\"" + base64WithPrefix + "\"}";
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://slip-s.oiio.download/api/slip/" + amountRequested))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                    .build();

            HttpResponse<String> slipResp = http.send(request, HttpResponse.BodyHandlers.ofString());
            JsonNode bodyJson = mapper.readTree(slipResp.body());

            if (slipResp.statusCode() != 200 || !bodyJson.has("data")) {
                throw new SlipCheckException("ไม่สามารถตรวจสอบสลิปได้", HttpStatus.BAD_REQUEST);
            }
            JsonNode data = bodyJson.get("data");

            // 2) ตรวจจำนวนเงิน
            double amountFromSlip = data.path("amount").asDouble();
            if (Math.abs(amountFromSlip - amountRequested) > 0.009) {
                throw new SlipCheckException("ยอดในสลิปไม่ตรงกับที่ระบุ", HttpStatus.BAD_REQUEST);
            }

            // 3) ตรวจเลข 4 ตัวท้ายผู้รับ (รองรับรูปแบบที่เป็น mask/เบอร์/เลขบัญชี)
            String recvIdRaw = data.path("receiver_id").asText(""); // เช่น "09xxxx0700" / "XXX-X-XX924-3" / "XXXXXXXXX0208"
            String recvLast4 = last4FromId(recvIdRaw);
            if (recvLast4.isEmpty()) {
                throw new SlipCheckException("ไม่สามารถอ่านเลข 4 ตัวท้ายผู้รับจากสลิปได้", HttpStatus.BAD_REQUEST);
            }
            if (!expectedLast4.equals(recvLast4)) {
                throw new SlipCheckException("เลข 4 ตัวท้ายผู้รับไม่ตรง", HttpStatus.BAD_REQUEST);
            }

            // 4) ตรวจเวลาในสลิป (เลือก diff น้อยสุดระหว่าง UTC vs เวลาไทย)
            String isoTime = data.path("date").asText(""); // เช่น "2025-08-17T05:30:00Z"
            if (isoTime.isEmpty()) {
                throw new SlipCheckException("ไม่พบเวลาจากสลิป", HttpStatus.BAD_REQUEST);
            }

            Instant parsedAsUtc = tryParseUtc(isoTime);
            Instant parsedAsThai = tryParseThai(isoTime);

            if (parsedAsUtc == null && parsedAsThai == null) {
                throw new SlipCheckException("รูปแบบเวลาในสลิปไม่ถูกต้อง: " + isoTime, HttpStatus.BAD_REQUEST);
            }

            Instant nowUtc = Instant.now();
            long diffUtcMin = Long.MAX_VALUE;
            long diffThMin  = Long.MAX_VALUE;
            if (parsedAsUtc != null) {
                long sec = Math.abs(Duration.between(parsedAsUtc, nowUtc).getSeconds());
                diffUtcMin = (sec + 59) / 60;
            }
            if (parsedAsThai != null) {
                long sec = Math.abs(Duration.between(parsedAsThai, nowUtc).getSeconds());
                diffThMin = (sec + 59) / 60;
            }

            long bestDiff = Math.min(diffUtcMin, diffThMin);
            Instant txChosen = (bestDiff == diffUtcMin ? parsedAsUtc : parsedAsThai);

            if (bestDiff > (WINDOW_MINUTES + SKEW_MINUTES)) {
                throw new SlipCheckException(
                        String.format("เวลาสลิปอยู่นอกช่วง: diff=%d นาที, window=%d+%d นาที",
                                bestDiff, WINDOW_MINUTES, SKEW_MINUTES),
                        HttpStatus.BAD_REQUEST
                );
            }

            // (ออปชัน) debug log
            System.out.printf(
                    "RAW=%s | asUTC=%s(%d min) | asTH=%s(%d min) | chosen=%s(%d min)%n",
                    isoTime,
                    parsedAsUtc, (diffUtcMin==Long.MAX_VALUE?-1:diffUtcMin),
                    (parsedAsThai==null?null:parsedAsThai.atZone(ZONE_TH)), (diffThMin==Long.MAX_VALUE?-1:diffThMin),
                    txChosen, bestDiff
            );

            return new SlipCheckResult(data, amountFromSlip, txChosen, bestDiff);

        } catch (SlipCheckException e) {
            throw e;
        } catch (Exception e) {
            throw new SlipCheckException("ไม่สามารถตรวจสอบสลิปได้: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    // ---------- helpers ----------
    private static Instant tryParseUtc(String iso) {
        try { return Instant.parse(iso); } catch (Exception ignored) { return null; }
    }

    private static Instant tryParseThai(String iso) {
        try {
            String cleaned = iso.replace("Z", "");
            DateTimeFormatter fmt = (cleaned.contains("."))
                    ? DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS")
                    : DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");
            LocalDateTime local = LocalDateTime.parse(cleaned, fmt);
            return local.atZone(ZONE_TH).toInstant();
        } catch (Exception ignored) {
            return null;
        }
    }

    /** ตัดมาเฉพาะ “ตัวเลขท้าย 4 หลัก” จากรูปแบบ receiver_id ที่อาจมี mask/dash */
    public static String last4FromId(String raw) {
        if (raw == null) return "";
        String digits = raw.replaceAll("\\D+", ""); // เก็บเฉพาะตัวเลข
        if (digits.length() < 4) return "";
        return digits.substring(digits.length() - 4);
    }
}
