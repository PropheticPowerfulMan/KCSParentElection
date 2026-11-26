import type{Metadata}from'next';
export const metadata:Metadata={applicationName:'KCS Student Election',manifest:'/student-government/manifest.webmanifest',appleWebApp:{capable:true,title:'KCS Students',statusBarStyle:'default'}};
export default function StudentElectionLayout({children}:{children:React.ReactNode}){return children}
