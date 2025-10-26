package com.finalproject.repository;


import com.finalproject.model.Member;
import com.finalproject.model.MemberTrip;
import com.finalproject.model.Trip;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface TripRepository extends JpaRepository<Trip, Integer> {
    Optional<Trip> findTop1ByMemberTrips_Participant_EmailAndTripIdNotOrderByStartDateDesc(String email, Integer excludeTripId);
    Optional<Trip> findByTripId(Integer tripId);
    @Query("select t from Trip t where t.tripId = :tripId")
    List<Trip> findAllByTripId(@Param("tripId") Integer tripId);
    Optional<Trip> findTopByMemberTrips_Participant_EmailIgnoreCaseAndMemberTrips_MemberTripStatusIgnoreCaseAndTripIdNotOrderByTripIdDesc(
            String email, String status, Integer excludedTripId
    );
}

