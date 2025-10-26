package com.finalproject.service;

import com.finalproject.model.Activity;
import com.finalproject.model.Trip;
import com.finalproject.repository.ActivityRepository;
import com.finalproject.repository.TripRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class ActivityService {

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private TripRepository tripRepository;

    // ✅ ดึงกิจกรรมทั้งหมดของ Trip โดย Trip ID
    public List<Activity> getActivitiesByTripId(int tripId) {
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new RuntimeException("Trip not found"));

        return trip.getActivity(); // ดึงจาก Trip ที่ถือกิจกรรมไว้
    }

    public Activity getActivityById(int activityId) {
        return activityRepository.findById(activityId)
                .orElseThrow(() -> new RuntimeException("Activity not found with id: " + activityId));
    }
    // ✅ สร้างกิจกรรมใหม่ (และผูกกับ Trip)
    public Activity createActivity(Activity activity, int tripId) {
        Trip trip = tripRepository.findById(tripId)
                .orElseThrow(() -> new RuntimeException("Trip not found"));

        trip.getActivity().add(activity); // เพิ่มกิจกรรมเข้าไป
        tripRepository.save(trip); // save Trip พร้อมกิจกรรมใหม่

        return activity;
    }

    // ✅ แก้ไขกิจกรรม
    public Activity updateActivity(Activity updatedActivity) {
        Activity existing = activityRepository.findById(updatedActivity.getActivityId())
                .orElseThrow(() -> new RuntimeException("Activity not found"));

        existing.setActivityName(updatedActivity.getActivityName());
        existing.setActivityDetail(updatedActivity.getActivityDetail());
        existing.setActivityPrice(updatedActivity.getActivityPrice());
        existing.setImagePaymentaActivity(updatedActivity.getImagePaymentaActivity());
        existing.setActivityDateTime(updatedActivity.getActivityDateTime());

        return activityRepository.save(existing);
    }

    // ✅ ลบกิจกรรมตาม ID
    public void deleteActivity(int activityId) {
        Activity existing = activityRepository.findById(activityId)
                .orElseThrow(() -> new RuntimeException("Activity not found"));

        activityRepository.delete(existing);
    }
}
