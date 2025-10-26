package com.finalproject.repository;

import com.finalproject.model.MemberTripActivity;
import com.finalproject.model.MemberTripActivityId; // Import composite key
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Transactional
public interface MemberTripActivityRepository extends JpaRepository<MemberTripActivity, MemberTripActivityId> {

    /**
     * ลบ MemberTripActivity ทั้งหมดที่เกี่ยวข้องกับ activityId ที่ระบุ
     * @param activityId รหัสกิจกรรมที่ต้องการลบ
     */
    @Modifying
    @Query("DELETE FROM MemberTripActivity mta WHERE mta.activity.activityId = :activityId")
    void deleteByActivity_ActivityId(int activityId);

    /**
     * ดึงรายการ MemberTripActivity ทั้งหมดที่เกี่ยวข้องกับ activityId ที่ระบุ
     * @param activityId รหัสกิจกรรมที่ต้องการค้นหา
     * @return List ของ MemberTripActivity ที่ตรงเงื่อนไข
     */
    @Query("SELECT mta FROM MemberTripActivity mta WHERE mta.activity.activityId = :activityId")
    List<MemberTripActivity> findByActivity_ActivityId(int activityId);

    /**
     * ดึงรายการ MemberTripActivity ทั้งหมดที่เกี่ยวข้องกับ memberTripId ที่ระบุ
     * @param memberTripId รหัส MemberTrip ที่ต้องการค้นหา
     * @return List ของ MemberTripActivity ที่ตรงเงื่อนไข
     */
    @Query("SELECT mta FROM MemberTripActivity mta WHERE mta.memberTrip.memberTripId = :memberTripId")
    List<MemberTripActivity> findByMemberTripId(Integer memberTripId);

    void deleteByMemberTrip_Trip_TripId(Integer tripId);

    @Modifying
    @Transactional
    @Query("delete from MemberTripActivity mta where mta.memberTrip.trip.tripId = :tripId")
    void deleteAllByTripId(@Param("tripId") Integer tripId);
}