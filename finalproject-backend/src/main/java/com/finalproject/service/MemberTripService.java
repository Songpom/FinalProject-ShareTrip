package com.finalproject.service;

import com.finalproject.model.MemberTrip;
import com.finalproject.repository.MemberTripRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class MemberTripService {

    @Autowired
    private MemberTripRepository memberTripRepository;

    public MemberTrip save(MemberTrip memberTrip) {
        return memberTripRepository.save(memberTrip);
    }
    public boolean findMemberTripByEmailAndTripId(String email, Integer tripId) {
        boolean exists = memberTripRepository.existsByEmailAndTripId(email, tripId);
        System.out.println("Checking existsByEmailAndTripId: email=" + email + ", tripId=" + tripId + " => " + exists);
        return exists;
    }
    public boolean existsByEmailAndTripId(String email, int tripId) {
        return memberTripRepository.existsByParticipant_EmailAndTrip_TripId(email, tripId);
    }

}
