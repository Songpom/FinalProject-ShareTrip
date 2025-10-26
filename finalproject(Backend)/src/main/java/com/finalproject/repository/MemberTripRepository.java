package com.finalproject.repository;

import com.finalproject.model.MemberTrip;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface MemberTripRepository extends JpaRepository<MemberTrip, Integer> {

    @Query("SELECT CASE WHEN COUNT(mt) > 0 THEN true ELSE false END " +
            "FROM MemberTrip mt " +
            "WHERE mt.participant.email = :email AND mt.trip.tripId = :tripId")
    boolean existsByEmailAndTripId(@Param("email") String email, @Param("tripId") Integer tripId);

    boolean existsByParticipant_EmailAndTrip_TripId(String email, int tripId);


    @Query("SELECT mt FROM MemberTrip mt WHERE mt.trip.tripId = :tripId AND mt.participant.email = :email")
    Optional<MemberTrip> findByTripIdAndEmail(@Param("tripId") Long tripId, @Param("email") String email);

    @Query("SELECT mt FROM MemberTrip mt LEFT JOIN FETCH mt.payments WHERE mt.trip.tripId = :tripId AND mt.memberTripStatus IN :statuses")
    List<MemberTrip> findByTrip_TripIdAndMemberTripStatusInWithPayments(@Param("tripId") Integer tripId, @Param("statuses") List<String> statuses);

    List<MemberTrip> findByTrip_TripId(Integer tripId);
    void deleteByTrip_TripId(Integer tripId);

    @Query("""
        select mt
        from MemberTrip mt
        join fetch mt.participant p
        where mt.trip.tripId = :tripId
          and lower(mt.memberTripStatus) in :statuses
    """)
    List<MemberTrip> findMembersForSuggestion(
            @Param("tripId") Integer tripId,
            @Param("statuses") Collection<String> statuses
    );

    Optional<MemberTrip> findFirstByTrip_TripIdAndParticipant_Email(Integer tripId, String email);

    // นับจำนวนผู้เข้าร่วม (participant) ทั้งหมดของทริป
    long countByTrip_TripIdAndMemberTripStatusIgnoreCase(Integer tripId, String status);


}
