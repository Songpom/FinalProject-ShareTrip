package com.finalproject.controller;

import com.finalproject.model.Member;
import com.finalproject.service.MemberService;
import com.finalproject.service.MemberTripService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/members")
public class MemberController {

    @Autowired
    private MemberService memberService;
    @Autowired
    private MemberTripService memberTripService;

    @Value("${upload.dir}")
    private String uploadDir;

    @PostMapping("/login")
    public ResponseEntity<?> getlogin(@RequestBody Map<String, String> loginRequest) {
        try {
            String email = loginRequest.get("email");
            String password = loginRequest.get("password");

            Member member = memberService.getMemberByEmail(email);
            if (member == null) {
                return new ResponseEntity<>("อีเมลนี้ยังไม่ได้สมัครใช้งาน", HttpStatus.UNAUTHORIZED);
            }

            String stored = member.getPassword();

            // ตรวจด้วย PBKDF2
            boolean ok = PasswordUtil.verifyPassword(password, stored);

            // (ตัวเลือก) เผื่อฐานเก่ายังเก็บ plaintext — ให้ผ่านได้ชั่วคราว
            if (!ok && stored != null && stored.equals(password)) {
                ok = true;
                // และควรอัปเกรดให้เป็นฟอร์แมตใหม่หลังจากล็อกอินสำเร็จ
                try {
                    String newHash = PasswordUtil.createPassword(password);
                    member.setPassword(newHash);
                    memberService.updateMember(member);
                } catch (Exception ignore) {}
            }

            if (ok) {
                // อย่าคืน password ออกไปใน response
                member.setPassword(null);
                return new ResponseEntity<>(member, HttpStatus.OK);
            } else {
                return new ResponseEntity<>("อีเมลหรือรหัสผ่านไม่ถูกต้อง", HttpStatus.UNAUTHORIZED);
            }
        } catch (Exception e) {
            return new ResponseEntity<>("Server error", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
//
//    @GetMapping
//    public ResponseEntity<List<Member>> getAllMembers() {
//        try {
//            List<Member> members = memberService.getAllMembers();
//            return new ResponseEntity<>(members, HttpStatus.OK);
//        } catch (Exception e) {
//            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
//        }
//    }

    @GetMapping("/{email}")
    public ResponseEntity<Member> getMemberByEmail(@PathVariable("email") String email) {
        try {
            Member member = memberService.getMemberByEmail(email);
            return new ResponseEntity<>(member, HttpStatus.OK);
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    // ✅ สร้างสมาชิกพร้อมอัปโหลดรูป
    @PostMapping(consumes = {"multipart/form-data"})
    public ResponseEntity<?> getRegister(
            @RequestParam("username") String username,
            @RequestParam("password") String password,
            @RequestParam("firstName") String firstName,
            @RequestParam("lastName") String lastName,
            @RequestParam("email") String email,
            @RequestParam("tel") String tel,
            @RequestParam("promptpay_number") String promptpayNumber,
            @RequestParam("member_image") MultipartFile file
    ) {
        try {
            // 0) normalize email
            String normalizedEmail = (email == null ? "" : email.trim().toLowerCase());
            if (normalizedEmail.isEmpty()) {
                return ResponseEntity.badRequest()
                        .body(Map.of("status","error","message","อีเมลห้ามว่าง"));
            }

            // 0.1) เช็คเมลซ้ำ
            if (memberService.existsByEmail(normalizedEmail)) {
                return ResponseEntity.status(HttpStatus.CONFLICT)
                        .body(Map.of("status","error","message","ข้อมูลอีเมลซ้ำ กรุณาลองใหม่อีกครั้ง"));
            }

            // 1) ตั้งชื่อไฟล์
            String originalName = org.springframework.util.StringUtils.cleanPath(file.getOriginalFilename());
            String ext = (originalName != null && originalName.contains(".")) ?
                    originalName.substring(originalName.lastIndexOf('.')) : "";
            String safeUser = (username == null ? "user" : username.replaceAll("[^A-Za-z0-9]", ""));
            if (safeUser.isEmpty()) safeUser = "user";
            String fileName = "member_" + safeUser + "_" + System.currentTimeMillis() + ext;

            // 2) บันทึกรูป
            File saveFile = new File(uploadDir + fileName);
            saveFile.getParentFile().mkdirs();
            try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                fout.write(file.getBytes());
            }

            // 3) บันทึกสมาชิก
            Member member = new Member();
            member.setUsername(username);
            member.setPassword(PasswordUtil.createPassword(password));
            member.setFirstName(firstName);
            member.setLastName(lastName);
            member.setEmail(normalizedEmail); // ใช้ email ที่ normalize แล้ว
            member.setTel(tel);
            member.setPromtpayNumber(promptpayNumber);
            member.setMember_image(fileName);

            Member savedMember = memberService.createMember(member);
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(Map.of("status","ok","data", savedMember));

        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            // เผื่อชน unique ของ DB (กัน race condition)
            return ResponseEntity.status(HttpStatus.CONFLICT)
                    .body(Map.of("status","error","message","ข้อมูลอีเมลซ้ำ กรุณาลองใหม่อีกครั้ง"));
        } catch (IOException e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("status","error","message","เกิดข้อผิดพลาดในการบันทึกรูปภาพ"));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("status","error","message","ไม่สามารถสร้างสมาชิกได้"));
        }
    }



    @PostMapping("/search")
    public ResponseEntity<List<Map<String, Object>>> getListMember(@RequestBody Map<String, Object> request) {
        try {
            String keyword = (String) request.get("keyword");
            Integer tripId = (Integer) request.get("tripId");

            List<Member> results = memberService.searchFlexible(keyword);
            System.out.println("ผลลัพธ์ที่ค้นหาได้: " + results.size());
            for (Member m : results) {
                System.out.println(" - " + m.getUsername() + " | " + m.getEmail() + " | " + m.getFirstName() + " " + m.getLastName());
            }
            List<Map<String, Object>> responseList = new ArrayList<>();

            for (Member member : results) {
                boolean joined = memberTripService.findMemberTripByEmailAndTripId(member.getEmail(), tripId);
                Map<String, Object> map = new HashMap<>();
                map.put("member", member);
                map.put("joined", joined);
                responseList.add(map);
            }


            return new ResponseEntity<>(responseList, HttpStatus.OK);
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }




}
