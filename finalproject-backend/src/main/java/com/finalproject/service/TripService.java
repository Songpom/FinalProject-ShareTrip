package com.finalproject.service;

import com.finalproject.model.Trip;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public interface TripService {


    Trip createTrip(Trip trip);

    Trip updateTrip(Trip trip);

    boolean deleteTrip(Integer id);


    Trip getTripById(Integer id);

    List<Trip> getAllTrips();

    Optional<Trip> findLatestTripByMemberEmailExcludeTripId(String email, Integer excludeTripId);
}