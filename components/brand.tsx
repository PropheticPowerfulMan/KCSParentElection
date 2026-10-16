import Image from "next/image";
import Link from "next/link";
import kcsLogo from "@/public/kcs.jpg";
import {PrimaryNav} from "./primary-nav";

export function Brand({label="Parent Election",href="/"}:{label?:string;href?:string}){
 return <Link href={href} className="brand-link"><Image src={kcsLogo} alt="Kinshasa Christian School" width={54} height={54} priority className="brand-logo"/><span><b>KINSHASA CHRISTIAN SCHOOL</b><small>{label}</small></span></Link>
}
export function Header({studentGovernment=false}:{studentGovernment?:boolean}){
 return <header className="site-header"><div className="shell header-inner"><Brand label={studentGovernment?"Student Government Election":"Parent Election"} href={studentGovernment?"/student-government/":"/"}/>{!studentGovernment&&<PrimaryNav/>}</div></header>
}
