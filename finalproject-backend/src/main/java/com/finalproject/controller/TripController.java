package com.finalproject.controller;

import com.finalproject.model.Member;
import com.finalproject.model.MemberTrip;
import com.finalproject.model.Payment;
import com.finalproject.model.Trip;
import com.finalproject.repository.*;
import com.finalproject.service.MemberService;
import com.finalproject.service.TripService;
import jakarta.transaction.Transactional;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.*;

@RestController
@RequestMapping("/trips")
public class TripController {

    @Autowired
    private TripService tripService;
    @Autowired
    private MemberService memberService;
    @Autowired
    private PaymentRepository paymentRepository;
    @Autowired
    private MemberTripRepository memberTripRepository;
    @Autowired
    private TripRepository tripRepository;

    @Autowired
    private MemberTripActivityRepository memberTripActivityRepository;

    @Autowired
    private ActivityRepository activityRepository;

    private final String uploadDir = "C:/Users/HP/eclipse-workspace/FinalProject/src/main/java/com/finalproject/assets/"; // 📁 เปลี่ยนตำแหน่งจัดเก็บตามระบบคุณ


//    // Get all trips
//    @GetMapping
//    public ResponseEntity<List<Trip>> getAllTrips() {
//        try {
//            List<Trip> trips = tripService.getAllTrips();
//            return new ResponseEntity<>(trips, HttpStatus.OK);
//        } catch (Exception e) {
//            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
//        }
//    }

    // Get trip by ID
    @GetMapping("/{id}")
    public ResponseEntity<Trip> getTripDetail(@PathVariable("id") Integer id) {
        try {
            Trip trip = tripService.getTripById(id);
            if (trip != null) {
                return new ResponseEntity<>(trip, HttpStatus.OK);
            } else {
                return new ResponseEntity<>(HttpStatus.NOT_FOUND);
            }
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @PostMapping(value = "/create", consumes = {"multipart/form-data"})
    public ResponseEntity<?> doCreateTrip(
            @RequestParam("tripName") String tripName,
            @RequestParam("startDate") @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate startDate,
            @RequestParam("dueDate")   @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate dueDate,
            @RequestParam("budget") Double budget,
            @RequestParam("tripDetail") String tripDetail,
            @RequestParam("location") String location,
            @RequestParam("tripStatus") String tripStatus,
            @RequestParam("image") MultipartFile file,
            @RequestParam("memberName") String memberName
    ) {
        try {
            // เซฟรูป
            // 3) สร้างชื่อไฟล์ล่วงหน้า (ไม่ต้องใช้ tripId)
            String originalName = StringUtils.cleanPath(file.getOriginalFilename());
            String ext = (originalName != null && originalName.contains(".")) ?
                    originalName.substring(originalName.lastIndexOf('.')) : "";
            String fileName = "trip_" + System.currentTimeMillis() + ext;

            // 4) เซฟไฟล์
            File uploadFolder = new File(uploadDir);
            if (!uploadFolder.exists()) uploadFolder.mkdirs();
            File saveFile = new File(uploadDir + fileName);
            saveFile.getParentFile().mkdirs();
            try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                fout.write(file.getBytes());
            }

            // LocalDate -> Date (เวลา 00:00)
            ZoneId zone = ZoneId.of("Asia/Bangkok"); // โซนที่ต้องการ
            Instant startInstant = startDate.atTime(12, 0).atZone(zone).toInstant();
            Instant dueInstant   = dueDate.atTime(12, 0).atZone(zone).toInstant();

            Date startAsDate = Date.from(startInstant);
            Date dueAsDate   = Date.from(dueInstant);


            // สร้าง Trip
            Trip trip = new Trip();
            trip.setTripName(tripName);
            trip.setStartDate(startAsDate);
            trip.setDueDate(dueAsDate);
            trip.setBudget(budget);
            trip.setTripDetail(tripDetail);
            trip.setLocation(location);
            trip.setTripStatus(tripStatus);
            trip.setImage(fileName);

            // ดึงสมาชิก (owner)
            Member owner = memberService.getMemberByEmail(memberName);
            if (owner == null) {
                return new ResponseEntity<>("ไม่พบสมาชิก " + memberName, HttpStatus.NOT_FOUND);
            }

            // ทำ MemberTrip (owner) + Payment ค่าเข้าร่วม
            MemberTrip memberTrip = new MemberTrip();
            memberTrip.setTrip(trip);
            memberTrip.setParticipant(owner);
            memberTrip.setDateJoin(new Date());
            memberTrip.setMemberTripStatus("owner");

            Payment payment = new Payment();
            payment.setPrice(budget);
            payment.setPaymentStatus("Correct");
            payment.setPaymentDetail("ค่าเข้าร่วม");
            payment.setDatetimePayment(new Date());
            payment.setMembertrip(memberTrip);
            memberTrip.getPayments().add(payment);

            trip.getMemberTrips().add(memberTrip);

            Trip savedTrip = tripService.createTrip(trip);

            // ดึงสมาชิกจากทริปล่าสุดก่อนหน้านี้เพื่อใช้แนะนำในหน้า invite

            // ภายใน createTripWithImage หลังจาก savedTrip แล้ว
            String ownerEmail = memberName;
            Integer currentTripId = savedTrip.getTripId();

// หา "ทริปล่าสุดก่อนหน้า" ที่ user เป็น owner และไม่ใช่ทริปปัจจุบัน
            Optional<Trip> previousTripOpt =
                    tripRepository.findTopByMemberTrips_Participant_EmailIgnoreCaseAndMemberTrips_MemberTripStatusIgnoreCaseAndTripIdNotOrderByTripIdDesc(
                            ownerEmail, "owner", currentTripId
                    );

            List<Map<String,Object>> previousMembers = new ArrayList<>();
            if (previousTripOpt.isPresent()) {
                Trip prev = previousTripOpt.get();

                // ดึงสมาชิกที่ "เคยถูกเชิญ" หรือ "เคยเข้าร่วม" (อยากเอาอย่างใดอย่างหนึ่งค่อยปรับได้)
                List<String> statuses = List.of("invited", "participant"); // <- ปรับตรงนี้ตามระบบจริง
                List<MemberTrip> mts = memberTripRepository.findMembersForSuggestion(prev.getTripId(), statuses);

                // map เป็น payload ที่ frontend ต้องการ
                for (MemberTrip mt : mts) {
                    if (mt.getParticipant() == null) continue;
                    Member m = mt.getParticipant();

                    // ตัดตัวเองทิ้ง
                    if (m.getEmail() == null || m.getEmail().equalsIgnoreCase(ownerEmail)) continue;

                    Map<String, Object> simpleMember = new HashMap<>();
                    simpleMember.put("email", m.getEmail());
                    simpleMember.put("username", m.getUsername());
                    simpleMember.put("firstName", m.getFirstName());
                    simpleMember.put("lastName", m.getLastName());
                    // ส่งคีย์ "memberImage" เป็น camelCase ให้ตรงกับแอป
                    simpleMember.put("memberImage", m.getMember_image());
                    System.out.println("📤 [DEBUG] Sending memberImage in response: " + m.getMember_image());

                    Map<String, Object> info = new HashMap<>();
                    info.put("member", simpleMember);
                    // แค่ "เสนอชื่อ" ในทริปใหม่ -> ยังไม่เชิญ
                    info.put("status", false);

                    previousMembers.add(info);
                }
            }

            Map<String,Object> response = new HashMap<>();
            response.put("status", "success");
            response.put("message", "สร้างทริปสำเร็จ");
            response.put("tripId", currentTripId);
            response.put("lastTripMembers", previousMembers);

            return new ResponseEntity<>(response, HttpStatus.CREATED);


        } catch (IOException e) {
            return new ResponseEntity<>("เกิดข้อผิดพลาดในการอัปโหลดภาพ", HttpStatus.INTERNAL_SERVER_ERROR);
        } catch (Exception e) {
            e.printStackTrace();
            return new ResponseEntity<>("ไม่สามารถสร้างทริปได้: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }


    @PutMapping(value = "/update", consumes = {"multipart/form-data"})
    @Transactional
    public ResponseEntity<?> doEditTrip(
            @RequestParam("tripId") Integer tripId,
            @RequestParam("tripName") String tripName,
            @RequestParam("startDate") @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate startDate,
            @RequestParam("dueDate")   @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate dueDate,
            @RequestParam("budget") Double budget,
            @RequestParam("tripDetail") String tripDetail,
            @RequestParam("location") String location,
            @RequestParam("tripStatus") String tripStatus,
            @RequestParam(value = "image", required = false) MultipartFile imageFile
    ) {
        try {
            Trip existingTrip = tripService.getTripById(tripId);
            if (existingTrip == null) {
                return new ResponseEntity<>("ไม่พบทริป", HttpStatus.NOT_FOUND);
            }

            // โหลดสมาชิก (เช็ค participant เพื่อ lock budget)
            List<MemberTrip> allMemberTrips = memberTripRepository.findByTrip_TripId(tripId);
            if (allMemberTrips == null) allMemberTrips = Collections.emptyList();

            Optional<MemberTrip> ownerOpt = allMemberTrips.stream()
                    .filter(mt -> mt != null && "owner".equalsIgnoreCase(mt.getMemberTripStatus()))
                    .findFirst();
            if (ownerOpt.isEmpty()) {
                return new ResponseEntity<>("ไม่พบผู้สร้างทริป (owner) ในทริปนี้", HttpStatus.BAD_REQUEST);
            }
            MemberTrip ownerMt = ownerOpt.get();

            boolean hasParticipant = allMemberTrips.stream()
                    .anyMatch(mt -> mt != null && "participant".equalsIgnoreCase(mt.getMemberTripStatus()));

            boolean wantChangeBudget = !Objects.equals(existingTrip.getBudget(), budget);
            if (hasParticipant && wantChangeBudget) {
                return new ResponseEntity<>(
                        "ไม่สามารถแก้ไขงบประมาณได้ เนื่องจากมีสมาชิกเข้าร่วม (participant) แล้ว",
                        HttpStatus.BAD_REQUEST
                );
            }

            // อัปเดตข้อมูลทั่วไป

            ZoneId zone = ZoneId.of("Asia/Bangkok");
            Date startAsDate = Date.from(startDate.atTime(12, 0).atZone(zone).toInstant());
            Date dueAsDate   = Date.from(dueDate.atTime(12, 0).atZone(zone).toInstant());
            existingTrip.setTripName(tripName);
            existingTrip.setStartDate(startAsDate);
            existingTrip.setDueDate(dueAsDate);
            existingTrip.setTripDetail(tripDetail);
            existingTrip.setLocation(location);
            existingTrip.setTripStatus(tripStatus);

            String oldImageName = existingTrip.getImage(); // เก็บชื่อเดิมไว้ก่อน
            String newImageName = null;

            if (imageFile != null && !imageFile.isEmpty()) {
                String originalName = StringUtils.cleanPath(imageFile.getOriginalFilename());
                String ext = (originalName != null && originalName.contains(".")) ?
                        originalName.substring(originalName.lastIndexOf('.')) : "";
                // ตั้งชื่อไฟล์ใหม่ตามสไตล์ที่ขอ
                newImageName = "trip_" + existingTrip.getTripId() + "_" + System.currentTimeMillis() + ext;

                // เซฟไฟล์ใหม่ (ก่อนลบไฟล์เก่าเพื่อกันไฟล์หายหากเขียนล้มเหลว)
                File uploadFolder = new File(uploadDir);
                if (!uploadFolder.exists()) uploadFolder.mkdirs();
                File saveFile = new File(uploadDir + newImageName);
                saveFile.getParentFile().mkdirs();
                try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                    fout.write(imageFile.getBytes());
                }

                // ตั้งค่า image เป็นชื่อใหม่
                existingTrip.setImage(newImageName);
            }
            if (!hasParticipant) {
                existingTrip.setBudget(budget);
            }

            Trip updatedTrip = tripService.updateTrip(existingTrip);

            if (newImageName != null && oldImageName != null && !oldImageName.isBlank()) {
                try {
                    java.nio.file.Files.deleteIfExists(java.nio.file.Paths.get(uploadDir + oldImageName));
                } catch (IOException ex) {
                    // ไม่ควรให้ fail ทั้งเมธอดเพราะลบไฟล์เก่าไม่ได้ — log/ignore
                    System.err.println("ลบไฟล์รูปเก่าไม่สำเร็จ: " + ex.getMessage());
                }
            }

            // อัปเดต/สร้าง payment ค่าเข้าร่วมของ owner ถ้ายังไม่มี participant
            if (!hasParticipant) {
                Optional<Payment> joinFeeOpt =
                        paymentRepository.findFirstByMembertrip_MemberTripIdAndPaymentDetail(
                                ownerMt.getMemberTripId(), "ค่าเข้าร่วม"
                        );

                Payment joinFee = joinFeeOpt.orElseGet(Payment::new);
                joinFee.setMembertrip(ownerMt);
                joinFee.setPaymentDetail("ค่าเข้าร่วม");
                joinFee.setPrice(budget);
                if (joinFee.getPaymentStatus() == null || joinFee.getPaymentStatus().isEmpty()) {
                    joinFee.setPaymentStatus("Correct");
                }
                joinFee.setDatetimePayment(new Date());
                paymentRepository.save(joinFee);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("status", "ok");
            response.put("message", "อัปเดตทริปสำเร็จ");
            response.put("tripId", updatedTrip.getTripId());
            response.put("budgetLocked", hasParticipant);

            return new ResponseEntity<>(response, HttpStatus.OK);

        } catch (IOException e) {
            return new ResponseEntity<>("เกิดข้อผิดพลาดในการอัปโหลดภาพ", HttpStatus.INTERNAL_SERVER_ERROR);
        } catch (Exception e) {
            e.printStackTrace();
            return new ResponseEntity<>("แก้ไขแผนการท่องเที่ยวไม่สำเร็จ: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
        }
    // Delete trip by ID
    @DeleteMapping("/{id}")
    @Transactional
    public ResponseEntity<?> doRemoveTrip(@PathVariable("id") Integer tripId) {
        try {
            // 0) หา Trip
            Trip trip = tripRepository.findById(tripId).orElse(null);
            if (trip == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body(Map.of("status", "not_found", "message", "ไม่พบทริป"));
            }

            // ✅ ถ้าทริปสิ้นสุดแล้ว ให้ลบได้เลย (ไม่ต้องสนจำนวนผู้เข้าร่วม/รีฟัน)
            final String status = trip.getTripStatus() == null ? "" : trip.getTripStatus().trim();
            final boolean isEndedTrip = "ทริปสิ้นสุด".equalsIgnoreCase(status);

            // 1) เช็คมี participant ไหม (เฉพาะกรณีที่ทริปยังไม่สิ้นสุดเท่านั้น)
            if (!isEndedTrip) {
                List<MemberTrip> memberTrips = memberTripRepository.findByTrip_TripId(tripId);
                boolean hasAnyParticipant = memberTrips != null && memberTrips.stream()
                        .anyMatch(mt -> mt != null && "participant".equalsIgnoreCase(mt.getMemberTripStatus()));
                if (hasAnyParticipant) {
                    return ResponseEntity.status(HttpStatus.CONFLICT)
                            .body(Map.of("status", "need_refund",
                                    "message", "ทริปนี้มีผู้เข้าร่วมแล้ว ต้องทำการคืนเงินก่อนลบ",
                                    "tripId", tripId));
                }
            }

            // 2) เก็บชื่อไฟล์ที่จะลบ (Trip/Activity/Payment)
            List<String> activityImages = activityRepository.findActivityImagesByTripId(tripId);
            List<String> paymentSlips  = paymentRepository.findPaymentSlipsByTripId(tripId);
            String tripImage           = trip.getImage(); // อาจเป็น null/ว่าง

            // 3) ลบความสัมพันธ์และข้อมูล (ลำดับปลอดภัย)
            memberTripActivityRepository.deleteAllByTripId(tripId);       // mta
            paymentRepository.deleteAllByTripId(tripId);                  // payments

            // หา activity ids แล้วลบ activity เป็นชุด
            List<Integer> activityIds = activityRepository.findActivityIdsByTripId(tripId);
            if (activityIds != null && !activityIds.isEmpty()) {
                activityRepository.deleteByIds(activityIds);              // activities
            }

            memberTripRepository.deleteByTrip_TripId(tripId);             // member_trip mapping
            tripRepository.deleteById(tripId);                            // trip

            // 4) ลบไฟล์ภาพในดิสก์
            safeDeleteFile(tripImage);
            if (activityImages != null) {
                activityImages.forEach(this::safeDeleteFile);
            }
            if (paymentSlips != null) {
                paymentSlips.forEach(this::safeDeleteFile);
            }

            return ResponseEntity.ok(
                    Map.of("status", "deleted", "message", "ลบทริปสำเร็จ", "tripId", tripId)
            );
        } catch (Exception e) {
            return new ResponseEntity<>("ลบแผนการท่องเที่ยวไม่สำเร็จ: " + e.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }

    }

    /** ลบไฟล์ในโฟลเดอร์อัปโหลดอย่างปลอดภัย */
    private void safeDeleteFile(String filename) {
        try {
            if (filename == null || filename.isBlank()) return;
            File f = new File(uploadDir + filename);
            if (f.exists() && f.isFile()) {
                if (!f.delete()) {
                    System.out.println("⚠️ ลบไฟล์ไม่สำเร็จ: " + f.getAbsolutePath());
                }
            }
        } catch (Exception e) {
            System.out.println("⚠️ ลบไฟล์ผิดพลาด: " + e.getMessage());
        }
    }

    @GetMapping("/check-join/{memberTripId}")
    public ResponseEntity<?> getPaymentJoin(@PathVariable Integer memberTripId) {

        MemberTrip mt = memberTripRepository.findById(memberTripId)
                .orElseThrow(() -> new RuntimeException("ไม่พบ MemberTrip ID: " + memberTripId));

        // กรองเฉพาะ paymentDetail = "ค่าเข้าร่วม"
        List<Payment> onlyJoinPayment = mt.getPayments().stream()
                .filter(p -> "ค่าเข้าร่วม".equalsIgnoreCase(p.getPaymentDetail()))
                .toList();

        // set กลับไปให้มีแค่ payment อันเดียว
        mt.setPayments(onlyJoinPayment);

        return ResponseEntity.ok(mt);
    }

}
