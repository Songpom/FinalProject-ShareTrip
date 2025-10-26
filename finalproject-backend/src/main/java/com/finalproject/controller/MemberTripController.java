package com.finalproject.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.finalproject.model.Member;
import com.finalproject.model.MemberTrip;
import com.finalproject.model.Payment;
import com.finalproject.model.Trip;
import com.finalproject.repository.MemberTripRepository;
import com.finalproject.repository.PaymentRepository;
import com.finalproject.service.MemberService;
import com.finalproject.service.MemberTripService;
import com.finalproject.service.TripService;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import com.github.pheerathach.ThaiQRPromptPay;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.*;

@RestController
@RequestMapping("/membertrips")
public class MemberTripController {

    @Autowired
    private MemberTripService memberTripService;

    @Autowired
    private MemberService memberService;

    @Autowired
    private TripService tripService;

    @Autowired
    private MemberTripRepository memberTripRepository;

    @Autowired
    private CheckSlipController checkSlip;



    @Autowired
    private PaymentRepository paymentRepository;

    private static final long WINDOW_MINUTES = 15L; // หน้าต่างอนุโลมจริง
    private static final long SKEW_MINUTES   = 5L;  // เผื่อ clock skew แค่เล็กน้อย (2–5 นาที)
    private static final ZoneId ZONE_TH = ZoneId.of("Asia/Bangkok");




    @Value("${upload.dir}")
    private String uploadDir;

    // ✅ POST: เชิญสมาชิกเข้าทริป
    @PostMapping("/invite")
    public ResponseEntity<?> doInviteMember(@RequestBody Map<String, String> request) {
        try {
            String email = request.get("email");
            Integer tripId = Integer.parseInt(request.get("tripId"));

            Member member = memberService.getMemberByEmail(email);
            if (member == null) {
                return new ResponseEntity<>("ไม่สามารถส่งคำเชิญได้", HttpStatus.NOT_FOUND);
            }

            Trip trip = tripService.getTripById(tripId);
            if (trip == null) {
                return new ResponseEntity<>("ไม่สามารถส่งคำเชิญได้", HttpStatus.NOT_FOUND);
            }

            MemberTrip memberTrip = new MemberTrip();
            memberTrip.setParticipant(member);
            memberTrip.setTrip(trip);
            memberTrip.setDateJoin(new Date());
            memberTrip.setMemberTripStatus("INVITED"); // หรือ PENDING, JOINED ตาม design

            MemberTrip saved = memberTripService.save(memberTrip);
            return new ResponseEntity<>(saved, HttpStatus.CREATED);

        } catch (Exception e) {
            return new ResponseEntity<>("ไม่สามารถส่งคำเชิญได้: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    @PostMapping("/byEmail")
    public ResponseEntity<?> getListMyTrip(@RequestBody Map<String, String> request) {
        try {
            String email = request.get("email");
            // ดึง Member ตามอีเมล
            Member member = memberService.getMemberByEmail(email);
            if (member == null) {
                return new ResponseEntity<>("ไม่พบสมาชิก", HttpStatus.NOT_FOUND);
            }

            // ดึงรายการ MemberTrip ของสมาชิกนี้
            List<MemberTrip> memberTrips = member.getMembertrips();
            List<Trip> resultTrips = new ArrayList<>();

            for (MemberTrip mt : memberTrips) {
                String status = mt.getMemberTripStatus();
                if ("owner".equalsIgnoreCase(status) || "participant".equalsIgnoreCase(status)|| "INVITED".equalsIgnoreCase(status)) {
                    resultTrips.add(mt.getTrip());
                }
            }

            return new ResponseEntity<>(resultTrips, HttpStatus.OK);
        } catch (Exception e) {
            e.printStackTrace();
            return new ResponseEntity<>("เกิดข้อผิดพลาดในการดึงข้อมูลทริป", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @PostMapping("/getpaymentdetail")
    public ResponseEntity<?> getPaymentDetail(@RequestBody Map<String, String> request) {
        try {
            String email = request.get("email");
            int tripId = Integer.parseInt(request.get("tripId"));

            // 1) สมาชิกอยู่ในทริปไหม
            if (!memberTripService.existsByEmailAndTripId(email, tripId)) {
                return new ResponseEntity<>("ไม่พบข้อมูลสมาชิกในทริปนี้", HttpStatus.NOT_FOUND);
            }

            // 2) ทริป
            Trip trip = tripService.getTripById(tripId);
            if (trip == null) {
                return new ResponseEntity<>("ไม่พบทริป", HttpStatus.NOT_FOUND);
            }
            double budget = trip.getBudget() == null ? 0.0 : trip.getBudget();

            // 3) ถ้างบ <= 0 → เข้าร่วมทันที
            if (budget <= 0.0) {
                Optional<MemberTrip> opt = memberTripRepository.findByTripIdAndEmail(Long.valueOf(tripId), email);
                if (opt.isEmpty()) {
                    return new ResponseEntity<>("ไม่พบข้อมูลสมาชิกในทริปนี้", HttpStatus.NOT_FOUND);
                }

                MemberTrip mt = opt.get();
                String status = mt.getMemberTripStatus() == null ? "" : mt.getMemberTripStatus();
                if (!"participant".equalsIgnoreCase(status) && !"owner".equalsIgnoreCase(status)) {
                    mt.setMemberTripStatus("participant");
                    memberTripRepository.save(mt);
                }

                Map<String, Object> resp = new HashMap<>();
                resp.put("status", "ok");
                resp.put("message", "เข้าร่วมสำเร็จ (ไม่ต้องชำระเงิน)");
                return new ResponseEntity<>(resp, HttpStatus.OK);
            }

            // 4) หาเจ้าของทริป + พร้อมเพย์
            MemberTrip ownerTrip = trip.getMemberTrips().stream()
                    .filter(mt -> "owner".equalsIgnoreCase(mt.getMemberTripStatus()))
                    .findFirst()
                    .orElse(null);

            if (ownerTrip == null) {
                return new ResponseEntity<>("ไม่พบผู้จัดตั้งของทริปนี้", HttpStatus.BAD_REQUEST);
            }
            if (ownerTrip.getParticipant() == null || ownerTrip.getParticipant().getPromtpayNumber() == null) {
                return new ResponseEntity<>("ไม่พบข้อมูลในการชำระเงิน", HttpStatus.BAD_REQUEST);
            }

            // ดึงเลขพร้อมเพย์ดิบจาก DB
            String raw = ownerTrip.getParticipant().getPromtpayNumber();
            String digits = raw.replaceAll("\\D", ""); // เอาเฉพาะตัวเลข

// ตรวจรูปแบบ
            if (!digits.matches("^\\d{13}$") && !digits.matches("^0\\d{9}$")) {
                return new ResponseEntity<>(
                        "ไม่พบข้อมูลในการชำระเงิน",
                        HttpStatus.BAD_REQUEST
                );
            }
            String qrbase64;
            BigDecimal amt = BigDecimal
                    .valueOf(budget)
                    .setScale(2, RoundingMode.HALF_UP);
// ใส่พร็อกซีตามรูปแบบ
            if (digits.matches("^\\d{13}$")) {
                ThaiQRPromptPay qr = new ThaiQRPromptPay.Builder().staticQR().creditTransfer().nationalId(digits).amount(new BigDecimal(amt.doubleValue())).build();
                qrbase64 = qr.drawToBase64(300, 300);// หรือเมธอดที่ไลบรารีคุณให้มา
                // บัตรประชาชน 13 หลัก
            } else {
                ThaiQRPromptPay qr = new ThaiQRPromptPay.Builder().staticQR().creditTransfer().mobileNumber(digits).amount(new BigDecimal(amt.doubleValue())).build();
                qrbase64 = qr.drawToBase64(300, 300);// หรือเมธอดที่ไลบรารีคุณให้มา
            }

            // จัด response
            Map<String, Object> res = new HashMap<>();
            trip.setMemberTrips(null);
            trip.setActivity(null);
            res.put("trip", trip);
            res.put("qrcode", qrbase64);
            res.put("promptpay", raw); // ส่งค่าเลขที่เก็บใน DB กลับไปด้วย

            return new ResponseEntity<>(res, HttpStatus.OK);

        } catch (Exception e) {
            return new ResponseEntity<>("ไม่พบข้อมูลในการชำระเงิน: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }


    @PostMapping(value = "/getcheckslip", consumes = {"multipart/form-data"})
    @Transactional
    public ResponseEntity<?> doMemberTrip(@RequestParam("slip_image") MultipartFile file,
                                          @RequestParam("amount") String amountStr,
                                          @RequestParam("tripId") Long tripId,
                                          @RequestParam("email") String email) {
        try {
            if (file == null || file.isEmpty()) {
                return new ResponseEntity<>("ไม่พบไฟล์สลิป", HttpStatus.BAD_REQUEST);
            }

            // ---- เตรียม Base64 + MIME (ยังไม่บันทึกรูป) ----
            String contentType = Optional.ofNullable(file.getContentType()).orElse("").toLowerCase();
            if (contentType.contains("heic") || contentType.contains("heif") || contentType.isEmpty()) {
                contentType = "image/jpeg";
            }
            String base64WithPrefix = "data:" + contentType + ";base64," +
                    Base64.getEncoder().encodeToString(file.getBytes());

            // ---- หา expectedLast4 จาก owner ของทริป ----
            Trip trip = tripService.getTripById(tripId.intValue());
            if (trip == null || trip.getMemberTrips() == null) {
                return new ResponseEntity<>("ไม่พบทริปหรือสมาชิกในทริป", HttpStatus.NOT_FOUND);
            }
            MemberTrip ownerTrip = trip.getMemberTrips().stream()
                    .filter(mt -> "owner".equalsIgnoreCase(mt.getMemberTripStatus()))
                    .findFirst().orElse(null);
            if (ownerTrip == null || ownerTrip.getParticipant() == null
                    || ownerTrip.getParticipant().getPromtpayNumber() == null) {
                return new ResponseEntity<>("ไม่พบหมายเลขพร้อมเพย์ของผู้จัดตั้ง", HttpStatus.BAD_REQUEST);
            }
            String expectedLast4 = last4(digitsOnly(ownerTrip.getParticipant().getPromtpayNumber()));

            // ---- ตรวจสลิป (ยังไม่บันทึกรูป) ----
            double amount = Double.parseDouble(amountStr);
            CheckSlipController.SlipCheckResult result = checkSlip.verifySlip(amount, base64WithPrefix, expectedLast4);

            // ---- หา/อัปเดตสมาชิกทริป ----
            Optional<MemberTrip> optionalMemberTrip = memberTripRepository.findByTripIdAndEmail(tripId, email);
            if (optionalMemberTrip.isEmpty()) {
                return new ResponseEntity<>("ไม่พบข้อมูลสมาชิกในทริป", HttpStatus.NOT_FOUND);
            }
            MemberTrip memberTrip = optionalMemberTrip.get();
            memberTrip.setMemberTripStatus("participant");
            memberTripRepository.save(memberTrip);

            // ---- สร้างชื่อไฟล์ & บันทึกรูป "หลังจากผ่านทั้งหมดแล้ว" ----
            String originalName = StringUtils.cleanPath(Objects.toString(file.getOriginalFilename(), ""));
            String ext = originalName.contains(".") ? originalName.substring(originalName.lastIndexOf('.')) : "";
            String fileName = "payjoin_" + tripId + "_" + System.currentTimeMillis() + ext;

            File folder = new File(uploadDir);
            if (!folder.exists() && !folder.mkdirs()) {
                throw new RuntimeException("ไม่สามารถสร้างโฟลเดอร์อัปโหลดรูปได้");
            }
            File saveFile = new File(uploadDir + fileName);
            try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                fout.write(file.getBytes());
            }

            // ---- บันทึก Payment (หลังจากไฟล์ถูกบันทึกแล้ว) ----
            Payment payment = new Payment();
            payment.setPrice(result.amountFromSlip);
            payment.setPaymentStatus("Correct");
            payment.setPaymentDetail("ค่าเข้าร่วม");
            payment.setDatetimePayment(new Date());
            payment.setPaymentSlip(fileName);
            payment.setMembertrip(memberTrip);
            paymentRepository.save(payment);

            JsonNode data = result.data; // สามารถส่งกลับหรือปรับแต่งข้อความเองได้
            return new ResponseEntity<>(data.toString(), HttpStatus.OK);

        } catch (CheckSlipController.SlipCheckException e) {
            return new ResponseEntity<>(e.getMessage(), e.status);
        } catch (Exception e) {
            // โยนออกเพื่อ rollback ถ้าอยากให้ไฟล์กับ DB สอดคล้องกัน
            return new ResponseEntity<>("ชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง: " + e.getMessage(),
                    HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }


    // ---------- Helpers ----------
    private static String digitsOnly(String s) {
        return (s == null) ? "" : s.replaceAll("\\D", "");
    }

    private static String last4(String digitsOnly) {
        if (digitsOnly == null) return "";
        int n = digitsOnly.length();
        return (n >= 4) ? digitsOnly.substring(n - 4) : "";
    }

    /**
     * ดึง "เลข 4 ตัวท้ายจริง" จากสตริงที่อาจมี X/x/เครื่องหมาย/ช่องว่าง/รหัสประเทศ
     * ทำงานแบบไล่จากขวาไปซ้าย เก็บเฉพาะตัวเลข จนครบ 4 ตัว
     * ตัวอย่าง:
     *  - "09xxxx0700"    -> "0700"
     *  - "XXX-X-XX924-3" -> "4923" (เพราะ digits ขวาไปซ้าย: 3,2,9,4 → กลับลำดับเป็น 4923)
     *  - "+66-xxx-xxx-0700" -> "0700"
     */
    private static String last4FromId(String any) {
        if (any == null || any.isEmpty()) return "";
        StringBuilder acc = new StringBuilder(4);
        for (int i = any.length() - 1; i >= 0; i--) {
            char c = any.charAt(i);
            if (c >= '0' && c <= '9') {
                acc.append(c);
                if (acc.length() == 4) break;
            }
        }
        if (acc.length() < 4) return "";
        return acc.reverse().toString();
    }
}
