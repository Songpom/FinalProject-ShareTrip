package com.finalproject.repository;

import com.finalproject.model.Activity;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ActivityRepository extends JpaRepository<Activity, Integer> {
    @Modifying
    @Transactional
    @Query(value = "DELETE FROM activity WHERE tripId = :tripId", nativeQuery = true)
    void deleteAllByTripIdNative(@Param("tripId") Integer tripId);

    // (ถ้าต้องการดึงรายการด้วย)
    @Query(value = "SELECT * FROM activity WHERE tripId = :tripId", nativeQuery = true)
    List<Activity> findAllByTripIdNative(@Param("tripId") Integer tripId);

    // ดึงชื่อไฟล์รูปกิจกรรมทั้งหมดของทริป (ผ่าน a.memberTripActivity -> memberTrip.trip.tripId)
    @Query("""
           select distinct a.imagePaymentaActivity
           from Activity a
           join a.memberTripActivity mta
           where mta.memberTrip.trip.tripId = :tripId
             and a.imagePaymentaActivity is not null
             and a.imagePaymentaActivity <> ''
           """)
    List<String> findActivityImagesByTripId(@Param("tripId") Integer tripId);

    // ดึง id ของ activity ที่อยู่ในทริปนี้ (ไว้ใช้ลบ activity เป็นชุด)
    @Query("""
           select distinct a.activityId
           from Activity a
           join a.memberTripActivity mta
           where mta.memberTrip.trip.tripId = :tripId
           """)
    List<Integer> findActivityIdsByTripId(@Param("tripId") Integer tripId);

    // ลบ activity ตามชุด id
    @Modifying
    @Transactional
    @Query("delete from Activity a where a.activityId in :ids")
    void deleteByIds(@Param("ids") List<Integer> ids);
}
