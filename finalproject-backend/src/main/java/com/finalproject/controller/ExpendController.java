package com.finalproject.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.finalproject.dto.ActivitySummaryDTO;
import com.finalproject.dto.MemberTripBalanceDTO;
import com.finalproject.model.*;
import com.finalproject.repository.MemberTripRepository;
import com.finalproject.repository.MemberTripActivityRepository;
import com.finalproject.repository.PaymentRepository;
import com.finalproject.service.TripService;
import com.github.pheerathach.ThaiQRPromptPay;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
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

@Controller
@RequestMapping("/expend")
public class ExpendController {

    @Autowired
    private MemberTripRepository memberTripRepository;

    @Autowired
    private TripService tripService;

    @Autowired
    private PaymentRepository paymentRepository;

    @Autowired
    private MemberTripActivityRepository memberTripActivityRepository;
    @Autowired
    private CheckSlipController checkSlip;

    @Value("${upload.dir}")
    private String uploadDir;

    private static final long WINDOW_MINUTES = 15L; // หน้าต่างอนุโลมจริง
    private static final long SKEW_MINUTES   = 5L;  // เผื่อ clock skew แค่เล็กน้อย (2–5 นาที)
    private static final ZoneId ZONE_TH = ZoneId.of("Asia/Bangkok");





    // DTO สำหรับเก็บข้อมูลยอดคงเหลือของแต่ละ MemberTrip



    // Endpoint เดิม: คำนวณยอดคงเหลือสำหรับ MemberTrip ตาม memberTripId
    @GetMapping("/balance/{memberTripId}")
    @ResponseBody
    public Double calculateExpendBalance(@PathVariable Integer memberTripId) {
        try {
            if (memberTripId == null) {
                throw new IllegalArgumentException("memberTripId ต้องไม่เป็น null");
            }

            Optional<MemberTrip> memberTripOpt = memberTripRepository.findById(memberTripId);
            if (!memberTripOpt.isPresent()) {
                throw new RuntimeException("MemberTrip ไม่พบสำหรับ ID: " + memberTripId);
            }

            MemberTrip memberTrip = memberTripOpt.get();

            double totalPayment = (memberTrip.getPayments() != null)
                    ? memberTrip.getPayments().stream()
                    .filter(payment -> payment != null && payment.getPrice() != null)
                    .mapToDouble(Payment::getPrice)
                    .sum()
                    : 0.0;

            List<MemberTripActivity> activities = memberTripActivityRepository.findByMemberTripId(memberTripId);
            double totalPricePerPerson = (activities != null)
                    ? activities.stream()
                    .filter(activity -> activity != null && activity.getPricePerPerson() != null)
                    .mapToDouble(MemberTripActivity::getPricePerPerson)
                    .sum()
                    : 0.0;

            double balance = totalPayment - totalPricePerPerson;

            return balance;

        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("เกิดข้อผิดพลาดในการคำนวณยอดคงเหลือ: " + e.getMessage());
        }
    }

    // Endpoint เดิม: คำนวณยอดคงเหลือสำหรับทุก MemberTrip
    @GetMapping("/all-balances")
    @ResponseBody
    public Double[] getAllMemberTripBalances() {
        try {
            List<MemberTrip> memberTrips = memberTripRepository.findAll();
            return memberTrips.stream()
                    .mapToDouble(memberTrip -> {
                        try {
                            double totalPayment = (memberTrip.getPayments() != null)
                                    ? memberTrip.getPayments().stream()
                                    .filter(payment -> payment != null && payment.getPrice() != null)
                                    .mapToDouble(Payment::getPrice)
                                    .sum()
                                    : 0.0;

                            List<MemberTripActivity> activities = memberTripActivityRepository.findByMemberTripId(memberTrip.getMemberTripId());
                            double totalPricePerPerson = (activities != null)
                                    ? activities.stream()
                                    .filter(activity -> activity != null && activity.getPricePerPerson() != null)
                                    .mapToDouble(MemberTripActivity::getPricePerPerson)
                                    .sum()
                                    : 0.0;

                            return totalPayment - totalPricePerPerson;
                        } catch (Exception e) {
                            System.err.println("Error calculating balance for MemberTrip ID: " +
                                    (memberTrip.getMemberTripId() != null ? memberTrip.getMemberTripId() : "unknown") +
                                    " - " + e.getMessage());
                            return 0.0;
                        }
                    })
                    .boxed()
                    .toArray(Double[]::new);
        } catch (Exception e) {
            throw new RuntimeException("เกิดข้อผิดพลาดในการคำนวณยอดคงเหลือทั้งหมด: " + e.getMessage());
        }
    }

    @GetMapping("/member-trips-balances/{tripId}")
    @ResponseBody
    public List<MemberTripBalanceDTO> getListExpend(@PathVariable Integer tripId) {
        try {
            if (tripId == null) {
                throw new IllegalArgumentException("tripId ต้องไม่เป็น null");
            }

            List<MemberTrip> memberTrips = memberTripRepository.findByTrip_TripId(tripId);
            if (memberTrips == null || memberTrips.isEmpty()) {
                throw new RuntimeException("ไม่พบ MemberTrip สำหรับ Trip ID: " + tripId);
            }

            List<MemberTripBalanceDTO> balances = new ArrayList<>();
            for (MemberTrip memberTrip : memberTrips) {
                try {
                    balances.add(validateExpend(memberTrip));
                } catch (Exception e) {
                    // กรณีเกิดปัญหาในรายบุคคล ให้ส่ง DTO ว่างกลับไป (ไม่ให้ทั้งลิสต์ล้ม)
                    balances.add(new MemberTripBalanceDTO(
                            null, null, 0.0, 0.0, 0.0, new ArrayList<>()
                    ));
                }
            }
            return balances;

        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("ไม่พบข้อมูลรายการสรุปค่าใช้จ่าย: " + e.getMessage());
        }
    }

    /**
     * คำนวณสรุปยอดของสมาชิก 1 คนในทริป:
     * - totalPayment: รวมเฉพาะ Payment ที่ status = "Correct"
     * - totalPricePerPerson: รวม pricePerPerson ของกิจกรรมที่อยู่ใน MemberTripActivity
     * - balance = totalPayment - totalPricePerPerson
     * - extraPaymentStatus: รวมสถานะของ payment ที่ paymentDetail = "เรียกเก็บเงินเพิ่มเติม"
     * - unpaidExtraAmount: ยอดของ "เรียกเก็บเงินเพิ่มเติม" ที่ยัง pending
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

        // ดึงกิจกรรมของสมาชิก
        List<MemberTripActivity> activities =
                memberTripActivityRepository.findByMemberTripId(memberTripId);

        double totalPricePerPerson = (activities != null)
                ? activities.stream()
                .filter(a -> a != null && a.getPricePerPerson() != null)
                .mapToDouble(MemberTripActivity::getPricePerPerson)
                .sum()
                : 0.0;

        double balance = totalPayment - totalPricePerPerson;

        // สร้างรายการสรุปกิจกรรม
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

        // ✅ เฉพาะ payment ที่เป็น "เรียกเก็บเงินเพิ่มเติม"
        List<Payment> extraPayments = payments.stream()
                .filter(p -> p != null && "เรียกเก็บเงินเพิ่มเติม".equals(p.getPaymentDetail()))
                .toList();

        // ✅ สถานะรวมของ extra payment
        String extraStatus = extraPayments.stream()
                .anyMatch(p -> "pending".equalsIgnoreCase(p.getPaymentStatus()))
                ? "pending"
                : "complete";

        // ✅ ยอดที่ "เรียกเก็บเพิ่ม" แต่ยังไม่จ่าย (sum เฉพาะ pending)
        double unpaidExtraAmount = extraPayments.stream()
                .filter(p -> "pending".equalsIgnoreCase(p.getPaymentStatus()) && p.getPrice() != null)
                .mapToDouble(Payment::getPrice)
                .sum();

        // ✅ ประกอบ DTO ส่งออก
        MemberTripBalanceDTO dto = new MemberTripBalanceDTO(
                memberTripId.longValue(),
                member,
                totalPayment,
                totalPricePerPerson,
                balance,
                activityDetails
        );
        dto.setExtraPaymentStatus(extraStatus);
        dto.setUnpaidExtraAmount(unpaidExtraAmount);

        return dto;
    }


    @PostMapping("/request-payment-extra")
    @ResponseBody
    public String doRequestExtraPayment(@RequestBody Map<String, Object> request) {
        try {
            // ดึง tripId
            Integer tripId = null;
            Object tripIdObj = request.get("tripId");
            if (tripIdObj instanceof Integer) {
                tripId = (Integer) tripIdObj;
            } else if (tripIdObj instanceof Number) {
                tripId = ((Number) tripIdObj).intValue();
            }
            if (tripId == null) {
                return "กรุณาส่ง tripId ด้วย";
            }

            // ดึง payments list
            Object paymentsObj = request.get("payments");
            if (!(paymentsObj instanceof List)) {
                return "ไม่มีข้อมูล payments ที่ส่งมา หรือข้อมูลไม่ถูกต้อง";
            }
            List<?> paymentsList = (List<?>) paymentsObj;
            if (paymentsList.isEmpty()) {
                return "ไม่มีข้อมูล payments ที่ส่งมา";
            }

            for (Object paymentObj : paymentsList) {
                if (!(paymentObj instanceof Map)) continue;

                Map<?, ?> paymentMap = (Map<?, ?>) paymentObj;
                Object memberTripIdObj = paymentMap.get("memberTripId");
                Object amountObj = paymentMap.get("amount");

                if (memberTripIdObj == null || amountObj == null) continue;

                Long memberTripId = null;
                Double amount = null;

                try {
                    if (memberTripIdObj instanceof Number) {
                        memberTripId = ((Number) memberTripIdObj).longValue();
                    } else {
                        memberTripId = Long.parseLong(memberTripIdObj.toString());
                    }
                    if (amountObj instanceof Number) {
                        amount = ((Number) amountObj).doubleValue();
                    } else {
                        amount = Double.parseDouble(amountObj.toString());
                    }
                } catch (Exception e) {
                    continue; // ข้ามถ้าแปลงค่าไม่ได้
                }

                if (amount == null || amount <= 0) continue;

                // แก้ไขตรงนี้ ให้ memberTripIdFinal เป็น final เพื่อใช้ใน lambda
                final Long memberTripIdFinal = memberTripId;

                MemberTrip memberTrip = memberTripRepository.findById(memberTripIdFinal.intValue())
                        .orElseThrow(() -> new RuntimeException("ไม่พบ MemberTrip ID: " + memberTripIdFinal));

                // ตรวจสอบว่า memberTrip นี้อยู่ใน tripId ที่ส่งมาหรือไม่
                if (!memberTrip.getTrip().getTripId().equals(tripId)) {
                    throw new RuntimeException("MemberTrip ID: " + memberTripIdFinal + " ไม่อยู่ใน Trip ID: " + tripId);
                }

                Payment payment = new Payment();
                payment.setMembertrip(memberTrip);
                payment.setPrice(amount);

                // เช็คว่า memberTripStatus เป็น owner หรือไม่
                if ("owner".equalsIgnoreCase(memberTrip.getMemberTripStatus())) {
                    payment.setPaymentStatus("Correct");
                } else {
                    payment.setPaymentStatus("pending");
                }

                payment.setPaymentDetail("เรียกเก็บเงินเพิ่มเติม");
                payment.setPaymentSlip(null);
                payment.setDatetimePayment(null);

                if (memberTrip.getPayments() == null) {
                    memberTrip.setPayments(new ArrayList<>());
                }
                memberTrip.getPayments().add(payment);

                memberTripRepository.save(memberTrip);
            }

            return "บันทึกเรียกเก็บเงินเพิ่มเติมสำเร็จ";
        } catch (Exception e) {
            e.printStackTrace();
            return "“ไม่สามารถบันทึกข้อมูลได้กรุณาลองใหม่: " + e.getMessage();
        }
    }



    @PostMapping("/getpaymentextradetail")
    public ResponseEntity<?> getExpendDetail(@RequestBody Map<String, String> request) {
        try {
            int memberTripId = Integer.parseInt(request.get("memberTripId"));
            int tripId = Integer.parseInt(request.get("tripId"));

            // ตรวจสอบว่า MemberTrip มีอยู่จริงไหม
            Optional<MemberTrip> optionalMemberTrip = memberTripRepository.findById(memberTripId);
            if (optionalMemberTrip.isEmpty()) {
                return new ResponseEntity<>("ไม่พบข้อมูล MemberTrip", HttpStatus.NOT_FOUND);
            }

            MemberTrip memberTrip = optionalMemberTrip.get();

            // ตรวจสอบว่า memberTrip นี้อยู่ใน trip เดียวกับ tripId หรือไม่
            if (memberTrip.getTrip() == null || memberTrip.getTrip().getTripId() != tripId) {
                return new ResponseEntity<>("MemberTrip ไม่อยู่ใน Trip ที่ระบุ", HttpStatus.BAD_REQUEST);
            }

            Trip trip = memberTrip.getTrip(); // ได้จาก memberTrip ด้านบนแล้ว ไม่ต้อง query ใหม่

            // ค้นหา owner ของทริป
            MemberTrip ownerTrip = trip.getMemberTrips().stream()
                    .filter(mt -> "owner".equalsIgnoreCase(mt.getMemberTripStatus()))
                    .findFirst()
                    .orElse(null);

            if (ownerTrip == null || ownerTrip.getParticipant() == null) {
                return new ResponseEntity<>("ไม่พบเจ้าของทริป", HttpStatus.NOT_FOUND);
            }

            // คำนวณยอดที่ต้องจ่ายจาก Payment
            List<Payment> pendingPayments = paymentRepository.findByMembertrip_MemberTripIdAndPaymentDetailAndPaymentStatus(
                    memberTripId, "เรียกเก็บเงินเพิ่มเติม", "pending"
            );

            double totalPendingAmount = pendingPayments.stream()
                    .mapToDouble(Payment::getPrice)
                    .sum();

            // ถ้าไม่มียอดค้าง ก็แจ้งเตือน
            if (totalPendingAmount <= 0) {
                return new ResponseEntity<>("ไม่มียอดเรียกเก็บเงินเพิ่มเติมที่ค้างอยู่", HttpStatus.OK);
            }

            // เตรียม response
            Map<String, Object> response = new HashMap<>();
            trip.setMemberTrips(null);
            trip.setActivity(null);
            response.put("trip", trip);
            response.put("amount", totalPendingAmount); // เผื่อใช้ในหน้า frontend ด้วย

            // สร้าง QR โค้ด
            // ดึงเลขพร้อมเพย์ดิบจาก DB
            String raw = ownerTrip.getParticipant().getPromtpayNumber();
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
                    .valueOf(totalPendingAmount)
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

            response.put("qrcode", qrbase64);

            return new ResponseEntity<>(response, HttpStatus.OK);

        } catch (Exception e) {
            return new ResponseEntity<>("บันทึกข้อมูลการชำระเงินเพิ่มเติมไม่สำเร็จ: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    @PostMapping(value = "/uploadextraslippayment", consumes = {"multipart/form-data"})
    @Transactional
    public ResponseEntity<?> doPaymentExpend(
            @RequestParam("memberTripId") int memberTripId,
            @RequestParam("tripId") int tripId,
            @RequestParam("amount") double amount,
            @RequestParam("slip_image") MultipartFile file
    ) {
        try {
            Optional<MemberTrip> optionalMemberTrip = memberTripRepository.findById(memberTripId);
            if (optionalMemberTrip.isEmpty()) {
                return new ResponseEntity<>("ไม่พบข้อมูล MemberTrip", HttpStatus.NOT_FOUND);
            }
            MemberTrip memberTrip = optionalMemberTrip.get();

            if (memberTrip.getTrip() == null || memberTrip.getTrip().getTripId() != tripId) {
                return new ResponseEntity<>("MemberTrip ไม่อยู่ใน Trip ที่ระบุ", HttpStatus.BAD_REQUEST);
            }

            // ✅ เตรียม Base64 + MIME (ยังไม่บันทึกรูป)
            String contentType = Optional.ofNullable(file.getContentType()).orElse("").toLowerCase();
            if (contentType.contains("heic") || contentType.contains("heif") || contentType.isEmpty()) {
                contentType = "image/jpeg";
            }
            String base64WithPrefix = "data:" + contentType + ";base64," +
                    Base64.getEncoder().encodeToString(file.getBytes());

            // ✅ expectedLast4 = ของ owner
            MemberTrip ownerTrip = memberTrip.getTrip().getMemberTrips().stream()
                    .filter(mt -> "owner".equalsIgnoreCase(mt.getMemberTripStatus()))
                    .findFirst().orElse(null);
            if (ownerTrip == null || ownerTrip.getParticipant() == null
                    || ownerTrip.getParticipant().getPromtpayNumber() == null) {
                return new ResponseEntity<>("ไม่พบหมายเลขพร้อมเพย์ของผู้จัดตั้ง", HttpStatus.BAD_REQUEST);
            }
            String expectedLast4 = last4(digitsOnly(ownerTrip.getParticipant().getPromtpayNumber()));

            // ✅ ตรวจสลิป (ยังไม่บันทึกรูป)
            CheckSlipController.SlipCheckResult result = checkSlip.verifySlip(amount, base64WithPrefix, expectedLast4);

            // ✅ ดึง payment pending
            List<Payment> pendingPayments = paymentRepository
                    .findByMembertrip_MemberTripIdAndPaymentDetailAndPaymentStatus(
                            memberTripId, "เรียกเก็บเงินเพิ่มเติม", "pending");
            if (pendingPayments.isEmpty()) {
                return new ResponseEntity<>("ไม่พบรายการเรียกเก็บเงินเพิ่มเติมที่รอชำระ", HttpStatus.BAD_REQUEST);
            }

            // ✅ สร้างชื่อไฟล์ & บันทึกรูป “หลังผ่านทั้งหมด”
            String originalName = StringUtils.cleanPath(Objects.toString(file.getOriginalFilename(), ""));
            String ext = originalName.contains(".") ? originalName.substring(originalName.lastIndexOf('.')) : "";
            String fileName = "expend_" + tripId + "_" + System.currentTimeMillis() + ext;

            File folder = new File(uploadDir);
            if (!folder.exists() && !folder.mkdirs()) {
                throw new RuntimeException("ไม่สามารถสร้างโฟลเดอร์อัปโหลดรูปได้");
            }
            File saveFile = new File(uploadDir + fileName);
            try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                fout.write(file.getBytes());
            }

            // ✅ อัปเดต payment หลังไฟล์ถูกบันทึกแล้ว
            for (Payment payment : pendingPayments) {
                payment.setPaymentStatus("Correct");
                payment.setPaymentSlip(fileName);
                payment.setDatetimePayment(new Date());
                paymentRepository.save(payment);
            }

            return new ResponseEntity<>("อัปโหลดและตรวจสอบสลิปเรียบร้อย", HttpStatus.OK);

        } catch (CheckSlipController.SlipCheckException e) {
            return new ResponseEntity<>(e.getMessage(), e.status);
        } catch (Exception e) {
            return new ResponseEntity<>("บันทึกข้อมูลการชำระเงินเพิ่มเติมไม่สำเร็จ: " + e.getMessage(),
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