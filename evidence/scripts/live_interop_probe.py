#!/usr/bin/env python3
"""
live_interop_probe.py - Diagnostic HTTP reachability probe for configured backend endpoints.
Standard baseline: Adapted from ISO/IEC 25010:2023 Interoperability sub-characteristic (Layer B).
All private hostnames, keys, and cloud identifiers are masked in output.
"""
import os
import urllib.request
import urllib.error
import ssl

def mask_host(host_str):
    if not host_str:
        return "<NOT_CONFIGURED>"
    return "<GEMINI_PROXY_HOST>"

def mask_cloud(cloud_str):
    if not cloud_str:
        return "<NOT_CONFIGURED>"
    return "<CLOUDINARY_CLOUD>"

def main():
    env_vars = {}
    if os.path.exists('.env'):
        with open('.env') as fp:
            for line in fp:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    env_vars[k.strip()] = v.strip().strip('"').strip("'")

    ctx = ssl.create_default_context()
    print("=== LIVE INTEROPERABILITY CHECKS (Layer B: Endpoint Reachability) ===")

    results = []

    # 1. Gemini Proxy Probe
    proxy_url = env_vars.get('GEMINI_PROXY_URL')
    if proxy_url:
        try:
            req = urllib.request.Request(proxy_url, headers={'User-Agent': 'CLARO-Audit/1.0'})
            with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
                status = response.getcode()
                results.append(('Gemini Proxy Endpoint', f'Host: {mask_host(proxy_url)}', status, status in [200, 204, 404, 405]))
        except urllib.error.HTTPError as e:
            # Receiving standard HTTP status (e.g. 405 Method Not Allowed) proves endpoint reachability
            results.append(('Gemini Proxy Endpoint', f'Host: {mask_host(proxy_url)}', e.code, e.code in [200, 400, 401, 403, 404, 405]))
        except Exception:
            results.append(('Gemini Proxy Endpoint', f'Host: {mask_host(proxy_url)}', 'ERROR', False))
    else:
        results.append(('Gemini Proxy Endpoint', 'Host: <NOT_CONFIGURED>', 'N/A', False))

    # 2. Cloudinary Probe
    cloud_name = env_vars.get('CLOUDINARY_CLOUD_NAME')
    if cloud_name:
        c_url = f"https://api.cloudinary.com/v1_1/{cloud_name}/image/upload"
        try:
            req = urllib.request.Request(c_url, headers={'User-Agent': 'CLARO-Audit/1.0'})
            with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
                status = response.getcode()
                results.append(('Cloudinary API Endpoint', f'Cloud: {mask_cloud(cloud_name)}', status, status in [200, 400, 401]))
        except urllib.error.HTTPError as e:
            results.append(('Cloudinary API Endpoint', f'Cloud: {mask_cloud(cloud_name)}', e.code, e.code in [200, 400, 401]))
        except Exception:
            results.append(('Cloudinary API Endpoint', f'Cloud: {mask_cloud(cloud_name)}', 'ERROR', False))
    else:
        results.append(('Cloudinary API Endpoint', 'Cloud: <NOT_CONFIGURED>', 'N/A', False))

    # 3. Firebase Identity Endpoint Probe
    fb_url = "https://identitytoolkit.googleapis.com/"
    try:
        req = urllib.request.Request(fb_url, headers={'User-Agent': 'CLARO-Audit/1.0'})
        with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
            status = response.getcode()
            results.append(('Firebase Identity Toolkit', '<FIREBASE_PROJECT>', status, status in [200, 404]))
    except urllib.error.HTTPError as e:
        results.append(('Firebase Identity Toolkit', '<FIREBASE_PROJECT>', e.code, e.code in [200, 404]))
    except Exception:
        results.append(('Firebase Identity Toolkit', '<FIREBASE_PROJECT>', 'ERROR', False))

    success_count = sum(1 for r in results if r[3])
    for service, target, status, passed in results:
        res_str = 'PASS' if passed else 'FAIL'
        print(f"Service: {service:<28} | Target: {target:<24} | HTTP Status: {str(status):<5} | Result: {res_str}")

    print(f"\nEndpoint Reachability Rate (X_reach): {success_count} / {len(results)} ({success_count/len(results)*100:.1f}%)")
    print("Notice: Endpoint reachability proves server availability and DNS routing; valid authenticated exchange is NOT TESTED (no dedicated test account).")

if __name__ == '__main__':
    main()
