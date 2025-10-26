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
@Table(name = "trip")
@AllArgsConstructor
@NoArgsConstructor
@Data
@JsonIgnoreProperties({"hibernateLazyInitializer", "handler"})
public class Trip {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "tripId")
    private Integer tripId;

    @Column(name = "tripName", nullable = false)
    private String tripName;

    @Column(name = "startDate", nullable = false)
    private Date startDate;

    @Column(name = "dueDate", nullable = false)
    private Date dueDate;

    @Column(name = "budget", nullable = false)
    private Double budget;

    @Column(name = "image", nullable = false)
    private String image;

    @Column(name = "tripDetail", nullable = false)
    private String tripDetail;

    @Column(name = "location", nullable = false)
    private String location;

    @Column(name = "tripStatus", nullable = false)
    private String tripStatus;

    @OneToMany(mappedBy = "trip", cascade = CascadeType.ALL)
    @JsonManagedReference
    private List<MemberTrip> memberTrips = new ArrayList<>();

    @OneToMany(cascade = CascadeType.ALL)
    @JoinColumn(name = "tripId", nullable = false)
    private List<Activity> activity = new ArrayList<>();
}
