package com.finalproject.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonManagedReference;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

@Entity
@Table(name = "activity")
@AllArgsConstructor
@NoArgsConstructor
@Data
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Activity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "activityId")
    private Integer activityId;

    @Column(name = "activityName", nullable = false)
    private String activityName;

    @Column(name = "activityDetail", nullable = false, columnDefinition = "TEXT")
    private String activityDetail;

    @Column(name = "activityPrice", nullable = false)
    private Double activityPrice;

    @Column(name = "imagePaymentaActivity", nullable = false)
    private String imagePaymentaActivity;

    @Column(name = "activityDateTime", nullable = false)
    private Date activityDateTime;

    @JsonManagedReference
    @OneToMany(mappedBy = "activity", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<MemberTripActivity> memberTripActivity;

}
