package com.finalproject.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.finalproject.dto.ActivitySummaryDTO;
import com.finalproject.dto.MemberTripBalanceDTO;
import com.finalproject.dto.TripSummaryDTO;
import com.finalproject.model.*;
import com.finalproject.repository.MemberTripActivityRepository;
import com.finalproject.repository.MemberTripRepository;
import com.finalproject.repository.PaymentRepository;
import com.finalproject.repository.TripRepository;
import com.github.pheerathach.ThaiQRPromptPay;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
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
@RequestMapping("/refund")
public class RefundController {
    @Autowired
    private MemberTripRepository memberTripRepository;

    @Autowired
    private MemberTripActivityRepository memberTripActivityRepository;

    @Autowired
    private TripRepository tripRepository;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private CheckSlipController checkSlip;

    @Value("${upload.dir}")
    private String uploadDir;

    private static final long WINDOW_MINUTES = 15L; // หน้าต่างอนุโลมจริง
    private static final long SKEW_MINUTES   = 5L;  // เผื่อ clock skew แค่เล็กน้อย (2–5 นาที)
    private static final ZoneId ZONE_TH = ZoneId.of("Asia/Bangkok");




    public RefundController(MemberTripRepository memberTripRepository,
                            MemberTripActivityRepository memberTripActivityRepository,
                            TripRepository tripRepository) {
        this.memberTripRepository = memberTripRepository;
        this.memberTripActivityRepository = memberTripActivityRepository;
        this.tripRepository = tripRepository;
    }

    @Transactional
    @GetMapping("/listrefundmember/{tripId}")
    @ResponseBody
    public TripSummaryDTO listRefundMember(@PathVariable Integer tripId) {
        if (tripId == null) {
            throw new IllegalArgumentException("tripId ต้องไม่เป็น null");
        }

        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new RuntimeException("ไม่พบข้อมูลทริปสำหรับ ID: " + tripId));

        List<String> statuses = Arrays.asList("participant", "owner");
        List<MemberTrip> memberTrips = memberTripRepository
                .findByTrip_TripIdAndMemberTripStatusInWithPayments(tripId, statuses);

        if (memberTrips == null || memberTrips.isEmpty()) {
            throw new RuntimeException("ไม่พบ MemberTrip สำหรับ Trip ID: " + tripId);
        }

        // หา email เจ้าของทริป (owner)
        String emailOwner = memberTrips.stream()
                .filter(mt -> "owner".equalsIgnoreCase(mt.getMemberTripStatus()) && mt.getParticipant() != null)
                .map(mt -> mt.getParticipant().getEmail())
                .findFirst()
                .orElse(null);

        // ใช้เมธอดคำนวณที่แยกออกมาแล้ว
        List<MemberTripBalanceDTO> balances = new ArrayList<>();
        for (MemberTrip mt : memberTrips) {
            try {
                balances.add(validateExpend(mt));
            } catch (Exception ex) {
                // กันล้มทั้งลิสต์ ถ้ารายคนผิดพลาด
                balances.add(new MemberTripBalanceDTO(
                        null, null, 0.0, 0.0, 0.0, new ArrayList<>()
                ));
            }
        }

        // ====== เช็คยอดรวมเพื่ออัปเดตสถานะทริป ======
        if (emailOwner != null) {
            final double EPS = 0.009;

            double sumAllBalances = balances.stream()
                    .mapToDouble(MemberTripBalanceDTO::getBalance)
                    .sum();

            double ownerBalance = balances.stream()
                    .filter(b -> b.getMember() != null
                            && b.getMember().getEmail() != null
                            && b.getMember().getEmail().equals(emailOwner))
                    .mapToDouble(MemberTripBalanceDTO::getBalance)
                    .findFirst()
                    .orElse(0.0);

            double othersSum = sumAllBalances - ownerBalance; // รวมของคนอื่น ๆ

            if (Math.abs(othersSum) <= EPS) {
                if (!"ทริปสิ้นสุด".equals(trip.getTripStatus())) {
                    trip.setTripStatus("ทริปสิ้นสุด");
                    tripRepository.save(trip);
                }
            }
        }
        // ================================================

        return new TripSummaryDTO(
                trip.getTripId(),
                trip.getTripName(),
                trip.getTripDetail(),
                emailOwner,
                balances
        );
    }

    /**
     * คำนวณสรุปยอดของสมาชิก 1 คนในทริป:
     * - totalPayment: รวม Payment ที่ status = "Correct"
     * - totalPricePerPerson: รวม pricePerPerson จาก MemberTripActivity
     * - balance = totalPayment - totalPricePerPerson
     * - แนบรายละเอียดกิจกรรมลงใน DTO
     *
     * หมายเหตุ: ถ้าในคลาสนี้มี validateExpend อยู่แล้วจาก endpoint อื่น
     * ให้ใช้ของเดิมได้เลยและลบตัวซ้ำนี้ออก
     */
    private MemberTripBalanceDTO validateExpend(MemberTrip memberTrip) {
        Integer memberTripId = memberTrip.getMemberTripId();
        Member member = memberTrip.getParticipant();

        // ป้องกัน null payments
        List<Payment> payments = (memberTrip.getPayments() != null)
                ? memberTrip.getPayments()
                : Collections.emptyList();

        double totalPayment = payments.stream()
                .filter(p -> p != null
                        && p.getPrice() != null
                        && "Correct".equalsIgnoreCase(p.getPaymentStatus()))
                .mapToDouble(Payment::getPrice)
                .sum();

        List<MemberTripActivity> activities =
                memberTripActivityRepository.findByMemberTripId(memberTripId);

        double totalPricePerPerson = (activities != null)
                ? activities.stream()
                .filter(a -> a != null && a.getPricePerPerson() != null)
                .mapToDouble(MemberTripActivity::getPricePerPerson)
                .sum()
                : 0.0;

        double balance = totalPayment - totalPricePerPerson;

        List<ActivitySummaryDTO> activityDetails = new ArrayList<>();
        if (activities != null) {
            for (MemberTripActivity mta : activities) {
                if (mta != null && mta.getActivity() != null) {
                    activityDetails.add(new ActivitySummaryDTO(
                            mta.getActivity().getActivityId(),
                            mta.getActivity().getActivityName(),
                            mta.getPricePerPerson(),
                            mta.getActivity().getActivityDateTime()
                    ));
                }
            }
        }

        return new MemberTripBalanceDTO(
                memberTripId.longValue(),
                member,
                totalPayment,
                totalPricePerPerson,
                balance,
                activityDetails
        );
    }



    @PostMapping("/refundmember/qrcode")
    @Transactional(readOnly = true)
    public ResponseEntity<?> getRefundDetail(@RequestBody Map<String, Object> request) {
        try {
            // 0) ตรวจอินพุต
            if (request == null || !request.containsKey("memberTripId")) {
                return new ResponseEntity<>("กรุณาส่ง memberTripId", HttpStatus.BAD_REQUEST);
            }

            Integer memberTripId;
            try {
                Object mtIdRaw = request.get("memberTripId");
                memberTripId = (mtIdRaw instanceof Number)
                        ? ((Number) mtIdRaw).intValue()
                        : Integer.parseInt(String.valueOf(mtIdRaw));
            } catch (Exception ex) {
                return new ResponseEntity<>("รูปแบบ memberTripId ไม่ถูกต้อง", HttpStatus.BAD_REQUEST);
            }

            // 1) หา MemberTrip
            MemberTrip memberTrip = memberTripRepository.findById(memberTripId)
                    .orElseThrow(() -> new RuntimeException("ไม่พบข้อมูล MemberTrip: " + memberTripId));

            Member member = memberTrip.getParticipant();
            if (member == null) {
                return new ResponseEntity<>("ไม่พบผู้ใช้ของ MemberTrip นี้", HttpStatus.NOT_FOUND);
            }

            // 2) totalPayment (เฉพาะ payment status = Correct)
            double totalPayment = 0.0;
            if (memberTrip.getPayments() != null) {
                totalPayment = memberTrip.getPayments().stream()
                        .filter(p -> p != null
                                && p.getPrice() != null
                                && "Correct".equalsIgnoreCase(p.getPaymentStatus()))
                        .mapToDouble(Payment::getPrice)
                        .sum();
            }

            // 3) totalPricePerPerson จาก MemberTripActivity
            List<MemberTripActivity> activities = memberTripActivityRepository.findByMemberTripId(memberTripId);
            double totalPricePerPerson = 0.0;
            if (activities != null) {
                totalPricePerPerson = activities.stream()
                        .filter(a -> a != null && a.getPricePerPerson() != null)
                        .mapToDouble(MemberTripActivity::getPricePerPerson)
                        .sum();
            }

            // 4) balance = totalPayment - totalPricePerPerson
            double balance = totalPayment - totalPricePerPerson;

            // ✅ ปัดเป็น 2 ตำแหน่งแบบ Half Up (กันทศนิยมยาวทำให้ ThaiQR ล่ม/500)
            BigDecimal balanceRounded = BigDecimal.valueOf(balance).setScale(2, RoundingMode.HALF_UP);

            // ถ้า balance <= 0 แปลว่าไม่ต้องคืน (หรือยังติดลบ)
            if (balanceRounded.compareTo(BigDecimal.ZERO) <= 0) {
                Map<String, Object> resp = new HashMap<>();
                resp.put("memberTripId", memberTripId);
                resp.put("amount", 0.00);
                resp.put("message", "ไม่มียอดที่ต้องคืน");
                return new ResponseEntity<>(resp, HttpStatus.OK);
            }

            // ดึงเลขพร้อมเพย์ดิบจาก DB
            String raw = memberTrip.getParticipant().getPromtpayNumber();
            String digits = raw.replaceAll("\\D", ""); // เอาเฉพาะตัวเลข

// ตรวจรูปแบบ
            if (!digits.matches("^\\d{13}$") && !digits.matches("^0\\d{9}$")) {
                return new ResponseEntity<>(
                        "รูปแบบพร้อมเพย์ไม่ถูกต้อง (ต้องเป็น 0XXXXXXXXX หรือเลขบัตร 13 หลัก)",
                        HttpStatus.BAD_REQUEST
                );
            }
            String qrbase64;
            BigDecimal amt = BigDecimal
                    .valueOf(balance)
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


            // 7) ตอบกลับ (memberTrip แบบย่อ)
            Map<String, Object> memberLite = new HashMap<>();
            memberLite.put("email", member.getEmail());
            memberLite.put("username", member.getUsername());
            memberLite.put("member_image", member.getMember_image());
            memberLite.put("firstName", member.getFirstName());
            memberLite.put("lastName", member.getLastName());
            memberLite.put("promtpayNumber", member.getPromtpayNumber());
            memberLite.put("tel", member.getTel());

            Map<String, Object> memberTripLite = new HashMap<>();
            memberTripLite.put("memberTripId", memberTrip.getMemberTripId());
            memberTripLite.put("member", memberLite);

            Map<String, Object> response = new HashMap<>();
            response.put("memberTrip", memberTripLite);
            response.put("amount", balanceRounded.doubleValue()); // ส่งกลับแบบปัดแล้ว
            response.put("imageName", "Refundmember");
            response.put("qrcode", qrbase64);

            return new ResponseEntity<>(response, HttpStatus.OK);

        } catch (Exception e) {
            return new ResponseEntity<>("เกิดข้อผิดพลาด: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    @PostMapping(value = "/upload-refund-slip", consumes = {"multipart/form-data"})
    @Transactional
    public ResponseEntity<?> doRefundPayment(
            @RequestParam("memberTripId") int memberTripId,
            @RequestParam(value = "tripId", required = false) Integer tripId,
            @RequestParam("amount") double amount,
            @RequestParam("slip_image") MultipartFile file
    ) {
        try {
            if (amount <= 0) {
                return new ResponseEntity<>("amount ต้องมากกว่า 0", HttpStatus.BAD_REQUEST);
            }

            // 1) ดึง MemberTrip และตรวจความสอดคล้อง tripId (ถ้ามีระบุ)
            MemberTrip memberTrip = memberTripRepository.findById(memberTripId)
                    .orElseThrow(() -> new RuntimeException("ไม่พบข้อมูล MemberTrip"));

            if (tripId != null) {
                if (memberTrip.getTrip() == null ||
                        !Objects.equals(memberTrip.getTrip().getTripId(), tripId)) {
                    return new ResponseEntity<>("MemberTrip ไม่อยู่ใน Trip ที่ระบุ", HttpStatus.BAD_REQUEST);
                }
            } else {
                tripId = (memberTrip.getTrip() != null) ? memberTrip.getTrip().getTripId() : null;
            }
            if (tripId == null) {
                return new ResponseEntity<>("ไม่พบ tripId ของ MemberTrip นี้", HttpStatus.BAD_REQUEST);
            }

            // 2) เตรียม Base64 + MIME (ยังไม่บันทึกรูป)
            String contentType = Optional.ofNullable(file.getContentType()).orElse("").toLowerCase();
            if (contentType.contains("heic") || contentType.contains("heif") || contentType.isEmpty()) {
                contentType = "image/jpeg";
            }
            String base64WithPrefix = "data:" + contentType + ";base64," +
                    Base64.getEncoder().encodeToString(file.getBytes());

            // 3) expectedLast4 = 4 ตัวท้ายของ "สมาชิกผู้รับเงินคืน"
            if (memberTrip.getParticipant() == null ||
                    memberTrip.getParticipant().getPromtpayNumber() == null) {
                return new ResponseEntity<>("ไม่พบหมายเลขพร้อมเพย์ของสมาชิกผู้รับเงินคืน", HttpStatus.BAD_REQUEST);
            }
            String expectedLast4 = last4(digitsOnly(memberTrip.getParticipant().getPromtpayNumber()));

            // 4) ตรวจสลิป (ยังไม่บันทึกรูป)
            CheckSlipController.SlipCheckResult result = checkSlip.verifySlip(amount, base64WithPrefix, expectedLast4);

            // 5) สร้างชื่อไฟล์ & บันทึกรูป “หลังผ่านทั้งหมด”
            String originalName = StringUtils.cleanPath(Objects.toString(file.getOriginalFilename(), ""));
            String ext = originalName.contains(".") ? originalName.substring(originalName.lastIndexOf('.')) : "";
            String fileName = "refund_" + memberTripId + "_" + System.currentTimeMillis() + ext;

            File saveFile = new File(uploadDir + fileName);
            File parent = saveFile.getParentFile();
            if (parent != null && !parent.exists() && !parent.mkdirs()) {
                throw new RuntimeException("ไม่สามารถสร้างโฟลเดอร์อัปโหลดรูปได้");
            }
            try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                fout.write(file.getBytes());
            }

            // 6) บันทึก Payment (refund_member เป็นค่าติดลบ) หลังไฟล์บันทึกแล้ว
            Payment payment = new Payment();
            payment.setMembertrip(memberTrip);
            payment.setPrice(-amount);
            payment.setPaymentStatus("Correct");
            payment.setPaymentDetail("refund_member");
            payment.setPaymentSlip(fileName);
            payment.setDatetimePayment(new Date());
            paymentRepository.save(payment);

            Map<String, Object> response = new HashMap<>();
            response.put("message", "อัปโหลดและสร้างรายการคืนเงินสำเร็จ");
            response.put("paymentId", payment.getPaymentId());
            response.put("memberTripId", memberTripId);
            response.put("amount", amount);
            response.put("priceSaved", payment.getPrice());
            response.put("paymentStatus", payment.getPaymentStatus());
            response.put("paymentDetail", payment.getPaymentDetail());
            response.put("slipFile", fileName);

            return new ResponseEntity<>(response, HttpStatus.CREATED);

        } catch (CheckSlipController.SlipCheckException e) {
            return new ResponseEntity<>(e.getMessage(), e.status);
        } catch (Exception e) {
            return new ResponseEntity<>("ไม่สามารถบันทึกข้อมูลหลักฐานการชำระเงินได้: " + e.getMessage(),
                    HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }



    /**
     * คืนครบทุกคน = สำหรับทุก MemberTrip ที่เป็น "participant" ในทริปนี้
     * ต้องมี Payment ที่ paymentDetail = "refund_member" และ (แนะนำ) paymentStatus = "Correct" อย่างน้อย 1 รายการ
     * (ไม่นับ owner)
     */
    private boolean isAllParticipantRefunded(Integer tripId) {
        // ดึง MemberTrip ทั้งหมดในทริปนี้
        List<MemberTrip> memberTrips = memberTripRepository.findByTrip_TripId(tripId);
        if (memberTrips == null || memberTrips.isEmpty()) {
            // ไม่มีใครเข้าร่วม ถือว่าครบโดยปริยาย (หรือจะ return false ก็ได้แล้วแต่นโยบาย)
            return true;
        }

        for (MemberTrip mt : memberTrips) {
            // ข้าม owner
            String status = (mt.getMemberTripStatus() == null) ? "" : mt.getMemberTripStatus().trim();
            if (!status.equalsIgnoreCase("participant")) {
                continue;
            }

            // หา payment ที่เป็น refund_member และ Correct
            boolean hasRefund =
                    mt.getPayments() != null &&
                            mt.getPayments().stream().anyMatch(p ->
                                    p != null &&
                                            "refund_member".equalsIgnoreCase(p.getPaymentDetail()) &&
                                            "Correct".equalsIgnoreCase(p.getPaymentStatus())
                            );

            if (!hasRefund) {
                return false; // เจอคนที่ยังไม่มีรายการคืน -> ยังไม่ครบ
            }
        }
        return true; // ทุก participant มี refund_member แล้ว
    }


    @PostMapping("/view")
    @Transactional(readOnly = true)
    public ResponseEntity<?> getViewRefund(@RequestBody Map<String, Object> request) {
        try {
            // 1) ดึงค่าจาก body
            Object tripIdRaw = request.get("tripId");
            Object emailRaw = request.get("email");

            if (tripIdRaw == null || emailRaw == null || String.valueOf(emailRaw).trim().isEmpty()) {
                return new ResponseEntity<>("กรุณาส่ง tripId และ email", HttpStatus.BAD_REQUEST);
            }

            Integer tripId;
            try {
                tripId = (tripIdRaw instanceof Number)
                        ? ((Number) tripIdRaw).intValue()
                        : Integer.parseInt(String.valueOf(tripIdRaw));
            } catch (NumberFormatException e) {
                return new ResponseEntity<>("tripId ต้องเป็นตัวเลข", HttpStatus.BAD_REQUEST);
            }
            String email = String.valueOf(emailRaw).trim();

            // 2) หา MemberTrip
            MemberTrip memberTrip = memberTripRepository
                    .findFirstByTrip_TripIdAndParticipant_Email(tripId, email)
                    .orElseThrow(() -> new RuntimeException(
                            "ไม่พบสมาชิกในทริป tripId=" + tripId + " email=" + email));

            // 3) หา Payment refund_member ล่าสุด
            Payment refundPayment = null;
            if (memberTrip.getPayments() != null && !memberTrip.getPayments().isEmpty()) {
                refundPayment = memberTrip.getPayments().stream()
                        .filter(p -> p != null && "refund_member".equalsIgnoreCase(p.getPaymentDetail()))
                        .sorted((p1, p2) -> {
                            Date d1 = p1.getDatetimePayment();
                            Date d2 = p2.getDatetimePayment();
                            if (d1 != null && d2 != null) {
                                return d2.compareTo(d1);
                            } else if (d1 != null) {
                                return -1;
                            } else if (d2 != null) {
                                return 1;
                            }
                            return Integer.compare(
                                    p2.getPaymentId() != null ? p2.getPaymentId() : 0,
                                    p1.getPaymentId() != null ? p1.getPaymentId() : 0
                            );
                        })
                        .findFirst()
                        .orElse(null);
            }

            // 4) สร้างข้อมูลตอบกลับ
            Map<String, Object> memberLite = new HashMap<>();
            if (memberTrip.getParticipant() != null) {
                Member m = memberTrip.getParticipant();
                memberLite.put("email", m.getEmail());
                memberLite.put("username", m.getUsername());
                memberLite.put("member_image", m.getMember_image());
                memberLite.put("firstName", m.getFirstName());
                memberLite.put("lastName", m.getLastName());
                memberLite.put("promtpayNumber", m.getPromtpayNumber());
                memberLite.put("tel", m.getTel());
            }

            Map<String, Object> memberTripLite = new HashMap<>();
            memberTripLite.put("memberTripId", memberTrip.getMemberTripId());
            memberTripLite.put("participant", memberLite);

            Map<String, Object> paymentJson = null;
            if (refundPayment != null) {
                paymentJson = new HashMap<>();
                paymentJson.put("paymentId", refundPayment.getPaymentId());
                paymentJson.put("paymentStatus", refundPayment.getPaymentStatus());
                paymentJson.put("price", refundPayment.getPrice());
                paymentJson.put("paymentDetail", refundPayment.getPaymentDetail());
                paymentJson.put("paymentSlip", refundPayment.getPaymentSlip());
                paymentJson.put("datetimePayment", refundPayment.getDatetimePayment());
            }

            Map<String, Object> response = new HashMap<>();
            response.put("memberTrip", memberTripLite);
            response.put("payment", paymentJson);

            return new ResponseEntity<>(response, HttpStatus.OK);

        } catch (RuntimeException ex) {
            return new ResponseEntity<>(ex.getMessage(), HttpStatus.NOT_FOUND);
        } catch (Exception e) {
            return new ResponseEntity<>("ไม่พบข้อมูลตามรหัสการค้นหา: " + e.getMessage(),
                    HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
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
