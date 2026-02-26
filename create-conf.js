import { resolve } from 'dns/promises'
import { writeFileSync, unlinkSync, existsSync } from 'fs';

const URLS = ["WIREGUARD_SERVER_ENDPOINT"];
const INTERFACE_WIFI = "wifi0";
const INTERFACE_ETH = "eth0";
const GATEWAY = "192.168.1.1";
const PUBLIC_KEY = "PUBLIC_KEY";
const PRIVATE_KEY = "PRIVATE_KEY";

function attachIPs(ips, endpoint, int) {
  let allPostups = "";
  let allPostdowns = "";
  for (let ip of ips) {
    allPostups += `PostUp = ip route add ${ip} via ${GATEWAY} dev ${int}\n`;
    allPostdowns += `PostDown = ip route del ${ip} via ${GATEWAY} dev ${int}\n`;
  }

  let CONFIG = `[Interface]
PrivateKey = ${PRIVATE_KEY}
Address = 10.28.200.113/32
DNS = 8.8.8.8, 8.8.4.4
MTU = 1300


# Linux Customization 
PostUp = ip -4 rule add not fwmark 0xca6c table 51820
PostUp = ip -4 route add default dev %i table 51820

${allPostups}
${allPostdowns}


[Peer]
PublicKey = ${PUBLIC_KEY}
Endpoint = ${endpoint}:908
AllowedIPs = 1.0.0.0/8, 2.0.0.0/7, 4.0.0.0/6, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/3, 96.0.0.0/6, 100.0.0.0/10, 100.128.0.0/9, 101.0.0.0/8, 102.0.0.0/7, 104.0.0.0/5, 112.0.0.0/4, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/6, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/10, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, ::/0
PersistentKeepalive = 3
`
  return CONFIG;

}

async function main() {
  console.log("")
  console.log("*********   Wireguard Configuartion Generator   *********")
  console.log("")
  console.log("   [-] Deleting old configs...\n  ")
  for (let [i, k] of Object.entries(URLS)) {
    let w = Number(i) + 1;
    const name1 = `./smart${w}-eth.conf`;
    const name2 = `./smart${w}-wifi.conf`;
    if (existsSync(name1)) unlinkSync(name1);
    if (existsSync(name2)) unlinkSync(name2);
  }

  let c = 1;
  for (let u of URLS) {
    const res = await resolve(u);
    console.log("IPs for ", u, "are", res.join(" , "))
    console.log("\n   [+] Generating Configuartion ::  \n")
    const fileDataWIFI = attachIPs(res, u, INTERFACE_WIFI);
    const fileDataETH = attachIPs(res, u, INTERFACE_ETH);
    writeFileSync(`./smart${c}-wifi.conf`, fileDataWIFI);
    console.log(fileDataWIFI)
    writeFileSync(`./smart${c}-eth.conf`, fileDataETH);
    console.log(fileDataETH)
    c++;
  }
}




main()
