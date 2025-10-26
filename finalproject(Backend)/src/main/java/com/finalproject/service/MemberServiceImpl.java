package com.finalproject.service;

import com.finalproject.model.Member;
import com.finalproject.repository.MemberRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public class MemberServiceImpl implements MemberService {

    @Autowired
    private MemberRepository memberRepository;


    @Override
    public boolean existsByEmail(String email) {
        if (email == null) return false;
        return memberRepository.existsByEmailIgnoreCase(email.trim().toLowerCase());
    }

    @Override
    public Member createMember(Member member) {
        return memberRepository.save(member);
    }

    @Override
    public Member updateMember(Member member) {
        Member existingMember = memberRepository.getReferenceById(member.getEmail());
        if (existingMember == null) {
            throw new RuntimeException("Member not found");
        }
        return memberRepository.save(member);
    }

    @Override
    public void deleteMember(String email) {
        Member member = memberRepository.getReferenceById(email);
        memberRepository.delete(member);
    }

    @Override
    public List<Member> getAllMembers() {
        return memberRepository.findAll();
    }

    @Override
    public Member getMemberByEmail(String email) {
        return memberRepository.getReferenceById(email);
    }



    @Override
    public List<Member> searchFlexible(String keyword) {
        keyword = keyword.trim();

        if (keyword.contains(" ")) {
            String[] parts = keyword.split("\\s+", 2); // แยกเป็น 2 ส่วนเท่านั้น
            String first = parts[0];
            String last = parts.length > 1 ? parts[1] : ""; // กัน IndexOutOfBoundsException
            return memberRepository.findByFirstNameContainingIgnoreCaseAndLastNameContainingIgnoreCase(first, last);
        } else {
            return memberRepository.findByUsernameContainingIgnoreCaseOrFirstNameContainingIgnoreCaseOrLastNameContainingIgnoreCase(
                    keyword, keyword, keyword
            );
        }
    }



}
