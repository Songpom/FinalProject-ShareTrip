package com.finalproject.dto;

import com.finalproject.model.Activity;

import java.util.Date;
import java.util.List;
public class ActivitySummaryDTO {
    private Integer activityId;
    private String activityName;
    private Double pricePerPerson;
    private Date activityDate;

    public ActivitySummaryDTO(Integer activityId, String activityName, Double pricePerPerson, Date activityDate) {
        this.activityId = activityId;       // เพิ่มบรรทัดนี้
        this.activityName = activityName;
        this.pricePerPerson = pricePerPerson;
        this.activityDate = activityDate;
    }

    public Integer getActivityId() { return activityId; }
    public String getActivityName() { return activityName; }
    public Double getPricePerPerson() { return pricePerPerson; }
    public Date getActivityDate() { return activityDate; }
}
