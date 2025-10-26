package com.finalproject.service;

import com.finalproject.model.Trip;
import com.finalproject.repository.TripRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class TripServiceImpl implements TripService {

    @Autowired
    private TripRepository tripRepository;

    // Create new trip
    @Override
    public Trip createTrip(Trip trip) {
        return tripRepository.save(trip);
    }

    // Update an existing trip
    @Override
    public Trip updateTrip(Trip trip) {
        if (tripRepository.existsById(trip.getTripId())) {
            return tripRepository.save(trip);
        } else {
            throw new RuntimeException("Trip not found");
        }
    }

    // Delete a trip by ID
    @Override
    public boolean deleteTrip(Integer id) {
        if (tripRepository.existsById(id)) {
            tripRepository.deleteById(id);
        } else {
            throw new RuntimeException("Trip not found");
        }
        return false;
    }

    // Get all trips
    @Override
    public List<Trip> getAllTrips() {
        return tripRepository.findAll();
    }

    @Override
    public Optional<Trip> findLatestTripByMemberEmailExcludeTripId(String email, Integer excludeTripId) {
        return tripRepository.findTop1ByMemberTrips_Participant_EmailAndTripIdNotOrderByStartDateDesc(email, excludeTripId);
    }

    // Get a trip by ID
    @Override
    public Trip getTripById(Integer id) {
        return tripRepository.findById(id).orElse(null);
    }
}
