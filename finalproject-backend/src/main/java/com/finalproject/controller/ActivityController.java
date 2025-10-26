package com.finalproject.controller;

import com.finalproject.model.Activity;
import com.finalproject.model.MemberTrip;
import com.finalproject.model.MemberTripActivity;
import com.finalproject.service.ActivityService;
import jakarta.servlet.annotation.MultipartConfig;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
@RestController
@RequestMapping("/activities")
@MultipartConfig
public class ActivityController {

    private final String uploadDir = "C:/Users/HP/eclipse-workspace/FinalProject/src/main/java/com/finalproject/assets/";

    @Autowired
    private ActivityService activityService;

    // ✅ ดึงกิจกรรมทั้งหมดในทริปตาม tripId
    @GetMapping("/trip/{tripId}")
    public ResponseEntity<List<Activity>> getListActivity(@PathVariable("tripId") int tripId) {
        try {
            List<Activity> activities = activityService.getActivitiesByTripId(tripId);
            return new ResponseEntity<>(activities, HttpStatus.OK);
        } catch (Exception e) {
            return new ResponseEntity<>(null, HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    // ✅ สร้างกิจกรรมพร้อมอัปโหลดรูป
    @PostMapping(value = "/create", consumes = {"multipart/form-data"})
    public ResponseEntity<?> doAddActivity(
            @RequestParam("activityName") String name,
            @RequestParam("activityDetail") String detail,
            @RequestParam("activityPrice") Double price,
            @RequestParam("activityDateTime") String dateTime, // ISO string: yyyy-MM-dd HH:mm:ss
            @RequestParam("tripId") Integer tripId,
            @RequestParam("image") MultipartFile file,
            @RequestParam("memberTripIds") List<Integer> memberTripIds,
            @RequestParam("pricePerPersons") List<Double> pricePerPersons
    ) {
        try {
            if (memberTripIds.size() != pricePerPersons.size()) {
                return new ResponseEntity<>("จำนวนสมาชิกกับราคาต่อคนไม่ตรงกัน", HttpStatus.BAD_REQUEST);
            }

            // 3) สร้างชื่อไฟล์ล่วงหน้า (ไม่ต้องใช้ tripId)
            String originalName = StringUtils.cleanPath(file.getOriginalFilename());
            String ext = (originalName != null && originalName.contains(".")) ?
                    originalName.substring(originalName.lastIndexOf('.')) : "";
            String fileName = "activity_"+tripId+"_"+ System.currentTimeMillis() + ext;

            // 4) เซฟไฟล์
            File uploadFolder = new File(uploadDir);
            if (!uploadFolder.exists()) uploadFolder.mkdirs();
            File saveFile = new File(uploadDir + fileName);
            saveFile.getParentFile().mkdirs();
            try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                fout.write(file.getBytes());
            }


            // 2. สร้าง Activity
            Activity activity = new Activity();
            activity.setActivityName(name);
            activity.setActivityDetail(detail);
            activity.setActivityPrice(price);
            activity.setActivityDateTime(java.sql.Timestamp.valueOf(dateTime));
            activity.setImagePaymentaActivity(fileName);

            // 3. ผูก memberTripActivity
            List<MemberTripActivity> mtaList = new ArrayList<>();
            for (int i = 0; i < memberTripIds.size(); i++) {
                Integer memberTripId = memberTripIds.get(i);
                Double pricePerPerson = pricePerPersons.get(i);

                MemberTrip memberTrip = new MemberTrip();
                memberTrip.setMemberTripId(memberTripId);

                MemberTripActivity mta = new MemberTripActivity();
                mta.setActivity(activity);
                mta.setMemberTrip(memberTrip);
                mta.setPricePerPerson(pricePerPerson);

                mtaList.add(mta);
            }

            activity.setMemberTripActivity(mtaList);

            // 4. บันทึกผ่าน service
            Activity saved = activityService.createActivity(activity, tripId);
            return new ResponseEntity<>(saved, HttpStatus.CREATED);

        } catch (IOException e) {
            return new ResponseEntity<>("บันทึกรูปไม่สำเร็จ", HttpStatus.INTERNAL_SERVER_ERROR);
        } catch (Exception e) {
            e.printStackTrace();
            return new ResponseEntity<>("ไม่สามารถบันทึกข้อมูลกิจกรรมได้กรุณาลองใหม่", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    // ✅ อัปเดตกิจกรรม
    // ✅ อัปเดตกิจกรรม
    @PutMapping(value = "/update/{id}", consumes = {"multipart/form-data"})
    public ResponseEntity<?> doEditActivity(
            @PathVariable("id") int id,
            @RequestParam("activityName") String name,
            @RequestParam("activityDetail") String detail,
            @RequestParam("activityPrice") Double price,
            @RequestParam("activityDateTime") String dateTime,
            @RequestParam("tripId") Integer tripId,
            @RequestParam(value = "image", required = false) MultipartFile file,
            @RequestParam("memberTripIds") List<Integer> memberTripIds,
            @RequestParam("pricePerPersons") List<Double> pricePerPersons
    ) {
        try {
            if (memberTripIds.size() != pricePerPersons.size()) {
                return new ResponseEntity<>("จำนวนสมาชิกกับราคาต่อคนไม่ตรงกัน", HttpStatus.BAD_REQUEST);
            }

            // ดึง Activity เก่าจาก DB
            Activity existing = activityService.getActivityById(id);
            if (existing == null) {
                return new ResponseEntity<>("ไม่พบกิจกรรมที่ต้องการอัปเดต", HttpStatus.NOT_FOUND);
            }

            // ===== จัดการไฟล์รูป: ถ้ามีรูปใหม่ให้เซฟใหม่ แล้วค่อยลบรูปเก่า =====
            String oldImageName = existing.getImagePaymentaActivity();
            String newImageName = null;

            if (file != null && !file.isEmpty()) {
                String originalName = StringUtils.cleanPath(file.getOriginalFilename());
                String ext = (originalName != null && originalName.contains(".")) ?
                        originalName.substring(originalName.lastIndexOf('.')) : "";

                // ตั้งชื่อใหม่: activity_<activityId>_<timestamp><ext>
                newImageName = "activity_" + tripId + "_" + System.currentTimeMillis() + ext;

                // เซฟไฟล์ใหม่ (ก่อนลบไฟล์เก่าเพื่อกันไฟล์หายหากเขียนล้มเหลว)
                File uploadFolder = new File(uploadDir);
                if (!uploadFolder.exists()) uploadFolder.mkdirs();

                File saveFile = new File(uploadDir + newImageName);
                saveFile.getParentFile().mkdirs();
                try (FileOutputStream fout = new FileOutputStream(saveFile)) {
                    fout.write(file.getBytes());
                }

                // ตั้งชื่อรูปใหม่ใน entity
                existing.setImagePaymentaActivity(newImageName);
            }
            // อัปเดตข้อมูล Activity
            existing.setActivityName(name);
            existing.setActivityDetail(detail);
            existing.setActivityPrice(price);
            existing.setActivityDateTime(java.sql.Timestamp.valueOf(dateTime));


            // สร้าง List<MemberTripActivity> ใหม่
            List<MemberTripActivity> mtaList = new ArrayList<>();
            for (int i = 0; i < memberTripIds.size(); i++) {
                Integer memberTripId = memberTripIds.get(i);
                Double pricePerPerson = pricePerPersons.get(i);

                MemberTrip memberTrip = new MemberTrip();
                memberTrip.setMemberTripId(memberTripId);

                MemberTripActivity mta = new MemberTripActivity();
                mta.setActivity(existing);
                mta.setMemberTrip(memberTrip);
                mta.setPricePerPerson(pricePerPerson);

                mtaList.add(mta);
            }

            existing.getMemberTripActivity().clear();
            existing.getMemberTripActivity().addAll(mtaList);


            // บันทึกข้อมูล
            Activity updated = activityService.updateActivity(existing);

            // ลบไฟล์เก่าหลังอัปเดตสำเร็จ (เฉพาะกรณีมีอัปโหลดใหม่จริง)
            if (newImageName != null && oldImageName != null && !oldImageName.isBlank()) {
                try {
                    java.nio.file.Files.deleteIfExists(java.nio.file.Paths.get(uploadDir + oldImageName));
                } catch (IOException ex) {
                    // ไม่อยากให้เมธอด fail เพราะลบไฟล์เก่าไม่ได้ — log ไว้พอ
                    System.err.println("ลบไฟล์รูปเก่าไม่สำเร็จ: " + ex.getMessage());
                }
            }

            return new ResponseEntity<>(updated, HttpStatus.OK);

        } catch (IOException e) {
            return new ResponseEntity<>("บันทึกรูปไม่สำเร็จ", HttpStatus.INTERNAL_SERVER_ERROR);
        } catch (Exception e) {
            e.printStackTrace();
            return new ResponseEntity<>("แก้ไขกิจกรรมไม่สำเร็จ", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }


    @DeleteMapping("/{id}")
    public ResponseEntity<?> doRemoveActivity(@PathVariable("id") int id) {
        try {
            // 1) ดึงกิจกรรมก่อน เพื่อเก็บชื่อไฟล์ไว้
            Activity activity = activityService.getActivityById(id);
            if (activity == null) {
                return new ResponseEntity<>(HttpStatus.NOT_FOUND);
            }
            String imageName = activity.getImagePaymentaActivity();

            // 2) ลบข้อมูลในฐานข้อมูล (รวมตารางกลางต่าง ๆ ตามที่ service จัดการ)
            activityService.deleteActivity(id);

            // 3) ลบไฟล์รูป (ถ้ามี)
            if (imageName != null && !imageName.isBlank()) {
                Path p = Paths.get(uploadDir + imageName);
                try {
                    Files.deleteIfExists(p);
                } catch (IOException ex) {
                    // ไม่ให้ล้มทั้งเมธอดเพราะลบไฟล์ไม่สำเร็จ — log ไว้พอ
                    System.err.println("ลบไฟล์รูปไม่สำเร็จ: " + p + " -> " + ex.getMessage());
                }
            }

            return new ResponseEntity<>(HttpStatus.OK);

        } catch (Exception e) {
            return new ResponseEntity<>("ลบกิจกรรมไม่สำเร็จ", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }
    // ✅ ดึงกิจกรรมตาม activityId
    @GetMapping("/{id}")
    public ResponseEntity<?> getActivityDetail(@PathVariable("id") int id) {
        try {
            Activity activity = activityService.getActivityById(id);
            if (activity == null) {
                return new ResponseEntity<>("ไม่พบข้อมูลกิจกรรม", HttpStatus.NOT_FOUND);
            }
            return new ResponseEntity<>(activity, HttpStatus.OK);
        } catch (Exception e) {
            return new ResponseEntity<>("เกิดข้อผิดพลาดขณะดึงข้อมูลกิจกรรม", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

}
