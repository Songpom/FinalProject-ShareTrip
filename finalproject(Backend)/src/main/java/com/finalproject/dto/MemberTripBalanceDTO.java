package com.finalproject.dto;

import com.finalproject.model.Member;
import java.util.List;

public class MemberTripBalanceDTO {
    private Long memberTripId; // ✅ เพิ่มฟิลด์ใหม่
    private Member member;
    private Double totalPayment;
    private Double totalPricePerPerson;
    private Double balance;
    private List<ActivitySummaryDTO> activities;
    private String extraPaymentStatus; // ✅ เพิ่ม status

    public Double getUnpaidExtraAmount() {
        return unpaidExtraAmount;
    }

    public void setUnpaidExtraAmount(Double unpaidExtraAmount) {
        this.unpaidExtraAmount = unpaidExtraAmount;
    }

    private Double unpaidExtraAmount;

    public String getExtraPaymentStatus() {
        return extraPaymentStatus;
    }

    public void setExtraPaymentStatus(String extraPaymentStatus) {
        this.extraPaymentStatus = extraPaymentStatus;
    }
    public MemberTripBalanceDTO(Long memberTripId, Member member, Double totalPayment, Double totalPricePerPerson, Double balance, List<ActivitySummaryDTO> activities) {
        this.memberTripId = memberTripId; // ✅ ตั้งค่า
        this.member = member;
        this.totalPayment = totalPayment;
        this.totalPricePerPerson = totalPricePerPerson;
        this.balance = balance;
        this.activities = activities;
    }

    // ✅ Getter ใหม่
    public Long getMemberTripId() {
        return memberTripId;
    }

    public Member getMember() {
        return member;
    }

    public Double getTotalPayment() {
        return totalPayment;
    }

    public Double getTotalPricePerPerson() {
        return totalPricePerPerson;
    }

    public Double getBalance() {
        return balance;
    }

    public List<ActivitySummaryDTO> getActivities() {
        return activities;
    }
}
