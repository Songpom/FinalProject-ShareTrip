package com.finalproject.service;

import com.finalproject.model.Member;
import com.finalproject.repository.MemberRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;


public interface MemberService {



    boolean existsByEmail(String email);

    Member createMember(Member member);

    Member updateMember(Member member);

    void deleteMember(String name);

    List<Member> getAllMembers();

    Member getMemberByEmail(String email);

    List<Member> searchFlexible(String input);






}