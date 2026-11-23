"use client";
import {Suspense} from "react";
import {useSearchParams} from "next/navigation";
import {ElectionAdmin} from "@/components/election-admin";
function Workspace(){const search=useSearchParams();return <ElectionAdmin audience="STUDENT" section={search.get("section")||"dashboard"}/>}
export default function Page(){return <Suspense fallback={<div className="ev-empty">KCS Orbit…</div>}><Workspace/></Suspense>}
