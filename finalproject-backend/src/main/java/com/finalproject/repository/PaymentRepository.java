package com.finalproject.repository;


import com.finalproject.model.Payment;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PaymentRepository extends JpaRepository<Payment, Integer> {

    List<Payment> findByMembertrip_MemberTripIdAndPaymentDetailAndPaymentStatus(
            Integer memberTripId, String paymentDetail, String paymentStatus
    );
    Optional<Payment> findFirstByMembertrip_MemberTripIdAndPaymentDetail(
            Integer memberTripId,
            String paymentDetail
    );

    void deleteByMembertrip_Trip_TripId(Integer tripId);

    Optional<Payment> findFirstByMembertrip_MemberTripIdAndPaymentDetailIgnoreCase(
            Integer memberTripId,
            String paymentDetail
    );

    // นับ "จำนวนคน" (distinct memberTrip) ที่มีสลิป refund_member สถานะ Correct ในทริปนั้น
    long countDistinctMembertrip_MemberTripIdByMembertrip_Trip_TripIdAndPaymentDetailIgnoreCaseAndPaymentStatusIgnoreCase(
            Integer tripId, String paymentDetail, String paymentStatus
    );

    // ดึงชื่อไฟล์สลิปทั้งหมดในทริป


    // ดึงชื่อไฟล์สลิปทั้งหมดของทริป
    @Query("""
           select p.paymentSlip
           from Payment p
           where p.membertrip.trip.tripId = :tripId
             and p.paymentSlip is not null
             and p.paymentSlip <> ''
           """)
    List<String> findPaymentSlipsByTripId(@Param("tripId") Integer tripId);

    // ลบ payment ทั้งทริป
    @Modifying
    @Transactional
    @Query("delete from Payment p where p.membertrip.trip.tripId = :tripId")
    void deleteAllByTripId(@Param("tripId") Integer tripId);
}
