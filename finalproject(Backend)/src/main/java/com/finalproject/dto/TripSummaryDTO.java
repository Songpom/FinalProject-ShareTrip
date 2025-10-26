package com.finalproject.dto;

import com.finalproject.dto.MemberTripBalanceDTO;

import java.util.List;

public class TripSummaryDTO {
    private Integer tripId;
    private String tripName;
    private String tripDetail;
    private String emailowner;
    private List<MemberTripBalanceDTO> memberBalances;

    public TripSummaryDTO() {
    }

    public TripSummaryDTO(Integer tripId, String tripName, String tripDetail, String emailowner,
                          List<MemberTripBalanceDTO> memberBalances) {
        this.tripId = tripId;
        this.tripName = tripName;
        this.tripDetail = tripDetail;
        this.emailowner = emailowner;
        this.memberBalances = memberBalances;
    }

    public Integer getTripId() {
        return tripId;
    }

    public void setTripId(Integer tripId) {
        this.tripId = tripId;
    }

    public String getTripName() {
        return tripName;
    }

    public void setTripName(String tripName) {
        this.tripName = tripName;
    }

    public String getTripDetail() {
        return tripDetail;
    }

    public void setTripDetail(String tripDetail) {
        this.tripDetail = tripDetail;
    }

    public String getEmailowner() {
        return emailowner;
    }

    public void setEmailowner(String emailowner) {
        this.emailowner = emailowner;
    }

    public List<MemberTripBalanceDTO> getMemberBalances() {
        return memberBalances;
    }

    public void setMemberBalances(List<MemberTripBalanceDTO> memberBalances) {
        this.memberBalances = memberBalances;
    }
}
